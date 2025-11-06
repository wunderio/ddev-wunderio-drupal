#!/bin/bash
set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

# Configure PHPUnit tests for the DDEV environment.
#
# Initially this was part of lando build process but we decided
# to commit the phpunit.xml. Still the functionality of this
# script could be useful as it always gets the latest distributed
# configuration from core. From time to time it wouldn't hurt
# try and update the file with 'lando regenerate-phpunit-config'.

PHPUNIT_CONFIG="$DDEV_APPROOT/phpunit.xml"

if [ -f "$PHPUNIT_CONFIG" ]; then
  rm "$PHPUNIT_CONFIG"
fi

cd $DDEV_APPROOT
cp -n "$DDEV_DOCROOT/core/phpunit.xml.dist" "$PHPUNIT_CONFIG"
sed -i "s|tests\/bootstrap\.php|${DDEV_DOCROOT}/core/tests/bootstrap.php|g" "$PHPUNIT_CONFIG"
sed -i "s|\.\/tests\/|${DDEV_DOCROOT}/core/tests/|g" "$PHPUNIT_CONFIG"
sed -i "s|directory>\.\/|directory>${DDEV_DOCROOT}/core/|g" "$PHPUNIT_CONFIG"
sed -i "s|directory>\.\.\/|directory>${DDEV_DOCROOT}/core/|g" "$PHPUNIT_CONFIG"
sed -i 's|<env name="SIMPLETEST_BASE_URL" value=""\/>|<env name="SIMPLETEST_BASE_URL" value="http://appserver_nginx" force="true"/>|g' "$PHPUNIT_CONFIG"
sed -i 's|<env name="SIMPLETEST_DB" value=""\/>|<env name="SIMPLETEST_DB" value="sqlite://localhost/tmp/db.sqlite"/>|g' "$PHPUNIT_CONFIG"

sed -i "s|<file>${DDEV_DOCROOT}/core/tests/TestSuites/UnitTestSuite.php</file>|<directory>${DDEV_DOCROOT}/modules/custom/*/tests/src/Unit</directory>|g" "$PHPUNIT_CONFIG"
sed -i "s|<file>${DDEV_DOCROOT}/core/tests/TestSuites/KernelTestSuite.php</file>|<directory>${DDEV_DOCROOT}/modules/custom/*/tests/src/Kernel</directory>|g" "$PHPUNIT_CONFIG"
sed -i "s|<file>${DDEV_DOCROOT}/core/tests/TestSuites/FunctionalTestSuite.php</file>|<directory>${DDEV_DOCROOT}/modules/custom/*/tests/src/Functional</directory>|g" "$PHPUNIT_CONFIG"
sed -i "s|<file>${DDEV_DOCROOT}/core/tests/TestSuites/FunctionalJavascriptTestSuite.php</file>|<directory>${DDEV_DOCROOT}/modules/custom/*/tests/src/FunctionalJavascript</directory>|g" "$PHPUNIT_CONFIG"

# Remove BuildTestSuite.php line with webroot variable
sed -i "/<file>${DDEV_DOCROOT//\//\\.}\/core\/tests\/TestSuites\/BuildTestSuite\.php<\/file>/d" "$PHPUNIT_CONFIG"

$DDEV_COMPOSER_ROOT/vendor/bin/phpunit --migrate-configuration
rm phpunit.xml.bak
