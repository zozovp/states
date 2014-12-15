Monitor
=======

Mandatory
---------

.. |deployment| replace:: proftpd

proftpd_procs
~~~~~~~~~~~~~

.. include:: /nrpe/doc/check_procs.inc

proftpd_port
~~~~~~~~~~~~

Check if the :doc:`/proftpd/doc/index` `port
<http://www.proftpd.org/docs/directives/linked/config_ref_Port.html>`_ is open.

proftpd_ftp
~~~~~~~~~~~

Check that a complete FTP handshake works.

.. include:: /postgresql/doc/monitor.inc

proftpd_backup_postgres_procs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Monitor :doc:`/proftpd/doc/index` backup process, critical if more than one backup processes running.

proftpd_backup
~~~~~~~~~~~~~~

.. include:: /backup/doc/monitor.inc