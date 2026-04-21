#!/usr/bin/env bash
# Descarga la test-lib de WordPress y prepara una DB de pruebas desechable.
#
# Uso:
#   bin/install-wp-tests.sh <db_name> <db_user> <db_pass> [db_host] [wp_version] [skip-db-create]
#
# Ejemplos:
#   bin/install-wp-tests.sh wordpress_test root root localhost latest
#   bin/install-wp-tests.sh wordpress_test root '' localhost 6.5 true

set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Uso: $0 <db_name> <db_user> <db_pass> [db_host] [wp_version] [skip-db-create]" >&2
    exit 1
fi

DB_NAME=$1
DB_USER=$2
DB_PASS=$3
DB_HOST=${4-localhost}
WP_VERSION=${5-latest}
SKIP_DB_CREATE=${6-false}

WP_TESTS_DIR=${WP_TESTS_DIR-/tmp/wordpress-tests-lib}
WP_CORE_DIR=${WP_CORE_DIR-/tmp/wordpress}

download() {
    if command -v curl >/dev/null 2>&1; then
        curl -s "$1" > "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -nv -O "$2" "$1"
    else
        echo "Necesitas curl o wget." >&2
        exit 1
    fi
}

if [[ $WP_VERSION =~ ^[0-9]+\.[0-9]+\-(beta|RC)[0-9]+$ ]]; then
    WP_BRANCH=${WP_VERSION%\-*}
    WP_TESTS_TAG="branches/$WP_BRANCH"
elif [[ $WP_VERSION =~ ^[0-9]+\.[0-9]+$ ]]; then
    WP_TESTS_TAG="branches/$WP_VERSION"
elif [[ $WP_VERSION =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    if [[ $WP_VERSION =~ [0-9]+\.[0-9]+\.[0]+ ]]; then
        WP_TESTS_TAG="tags/${WP_VERSION%??}"
    else
        WP_TESTS_TAG="tags/$WP_VERSION"
    fi
elif [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
    WP_TESTS_TAG="trunk"
else
    download http://api.wordpress.org/core/version-check/1.7/ /tmp/wp-latest.json
    grep '[0-9]+\.[0-9]+(\.[0-9]+)?' /tmp/wp-latest.json || true
    LATEST_VERSION=$(grep -o '"version":"[^"]*"' /tmp/wp-latest.json | head -n 1 | cut -d '"' -f 4)
    if [[ -z "$LATEST_VERSION" ]]; then
        echo "No se pudo determinar la versión de WordPress" >&2
        exit 1
    fi
    WP_TESTS_TAG="tags/$LATEST_VERSION"
fi

install_wp() {
    if [ -d "$WP_CORE_DIR" ]; then
        return
    fi
    mkdir -p "$WP_CORE_DIR"
    if [ "$WP_VERSION" == 'nightly' ] || [ "$WP_VERSION" == 'trunk' ]; then
        mkdir -p /tmp/wordpress-nightly
        download https://wordpress.org/nightly-builds/wordpress-latest.zip /tmp/wordpress-nightly/wordpress-nightly.zip
        unzip -q /tmp/wordpress-nightly/wordpress-nightly.zip -d /tmp/wordpress-nightly/
        mv /tmp/wordpress-nightly/wordpress/* "$WP_CORE_DIR"
    else
        if [ "$WP_VERSION" == 'latest' ]; then
            local ARCHIVE_NAME='latest'
        elif [[ $WP_VERSION =~ [0-9]+\.[0-9]+ ]]; then
            download https://api.wordpress.org/core/version-check/1.7/ /tmp/wp-latest.json
            LATEST_VERSION=$(grep -o '"version":"[^"]*"' /tmp/wp-latest.json | head -1 | cut -d '"' -f 4)
            if [[ -z "$LATEST_VERSION" ]]; then
                local ARCHIVE_NAME="wordpress-$WP_VERSION"
            else
                local ARCHIVE_NAME="wordpress-$WP_VERSION"
            fi
        else
            local ARCHIVE_NAME="wordpress-$WP_VERSION"
        fi
        download https://wordpress.org/${ARCHIVE_NAME}.tar.gz /tmp/wordpress.tar.gz
        tar --strip-components=1 -zxmf /tmp/wordpress.tar.gz -C "$WP_CORE_DIR"
    fi

    download https://raw.githubusercontent.com/markoheijnen/wp-mysqli/master/db.php "$WP_CORE_DIR/wp-content/db.php" || true
}

install_test_suite() {
    if [ ! -d "$WP_TESTS_DIR" ]; then
        mkdir -p "$WP_TESTS_DIR"
        svn co --quiet --ignore-externals https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/includes/ "$WP_TESTS_DIR/includes"
        svn co --quiet --ignore-externals https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/data/ "$WP_TESTS_DIR/data"
    fi

    if [ ! -f wp-tests-config.php ]; then
        download https://develop.svn.wordpress.org/${WP_TESTS_TAG}/wp-tests-config-sample.php "$WP_TESTS_DIR/wp-tests-config.php"
        WP_CORE_DIR=$(echo "$WP_CORE_DIR" | sed "s|/\$||")
        sed -i.bak "s:dirname( __FILE__ ) . '/src/':'$WP_CORE_DIR/':" "$WP_TESTS_DIR/wp-tests-config.php"
        sed -i.bak "s/youremptytestdbnamehere/$DB_NAME/" "$WP_TESTS_DIR/wp-tests-config.php"
        sed -i.bak "s/yourusernamehere/$DB_USER/" "$WP_TESTS_DIR/wp-tests-config.php"
        sed -i.bak "s/yourpasswordhere/$DB_PASS/" "$WP_TESTS_DIR/wp-tests-config.php"
        sed -i.bak "s|localhost|${DB_HOST}|" "$WP_TESTS_DIR/wp-tests-config.php"
    fi
}

recreate_db() {
    shopt -s nocasematch
    if [[ $1 =~ ^(y|yes)$ ]]; then
        mysqladmin drop "$DB_NAME" -f --user="$DB_USER" --password="$DB_PASS"$EXTRA
        create_db
        echo "Base de datos recreada"
    else
        echo "Cancelado."
        exit 1
    fi
    shopt -u nocasematch
}

create_db() {
    mysqladmin create "$DB_NAME" --user="$DB_USER" --password="$DB_PASS"$EXTRA
}

install_db() {
    if [ "${SKIP_DB_CREATE}" == "true" ]; then
        return 0
    fi

    local PARTS=(${DB_HOST//\:/ })
    local DB_HOSTNAME=${PARTS[0]}
    local DB_SOCK_OR_PORT=${PARTS[1]-}
    local EXTRA=""

    if ! [ -z "$DB_HOSTNAME" ] ; then
        if [ $(echo "$DB_SOCK_OR_PORT" | grep -e '^[0-9]\{1,\}$') ]; then
            EXTRA=" --host=$DB_HOSTNAME --port=$DB_SOCK_OR_PORT --protocol=tcp"
        elif ! [ -z "$DB_SOCK_OR_PORT" ] ; then
            EXTRA=" --socket=$DB_SOCK_OR_PORT"
        elif ! [ -z "$DB_HOSTNAME" ] ; then
            EXTRA=" --host=$DB_HOSTNAME --protocol=tcp"
        fi
    fi

    if [ $(mysql --user="$DB_USER" --password="$DB_PASS"$EXTRA --execute='show databases;' | grep ^$DB_NAME$) ]; then
        echo -n "La base de datos ${DB_NAME} ya existe. ¿Reiniciarla? [y/N]: "
        read DELETE_EXISTING_DB
        recreate_db $DELETE_EXISTING_DB
    else
        create_db
    fi
}

install_wp
install_test_suite
install_db
