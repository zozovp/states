/usr/local/nagios/lib/python2.7/check_backup_base.py:
  file:
    - absent

check_backup.py:
  file:
    - absent
    - name: /usr/lib/nagios/plugins/check_backup.py

{#-
Not all backup "driver" have a config file, but just erase that anyway.
 #}
/etc/nagios/backup.conf:
  file:
    - absent
