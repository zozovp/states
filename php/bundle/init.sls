include:
  - php

php_bundle:
  pkg:
    - installed
    - pkgs:
      - php5-gd
      - php5-mysql
      - php5-mcrypt
      - php5-curl
      - php5-cli
    - require:
      - pkgrepo: php