{#
 Uninstall SSMTP a simple interface to send mail to remote SMTP server
 #}
ssmtp:
  pkg:
    - purged
  file:
    - absent
    - name: /etc/ssmtp
    - require:
      - pkg: ssmtp

bsd-mailx:
  pkg:
    - purged
