Building Salt common documentation
==================================

You need sphinx to build the doc. Install it by run below commands::

  sudo apt-get update
  sudo apt-get install -y python-pip python-virtualenv

Then create a virtualenv and active it and run::

  pip install -r doc/requirements.txt

To create an HTML version of the docs, from **root directory of salt common**,
run::

  doc/build.py path_to_output_dir

Use ``../salt-doc`` if ``path_to_output_dir`` is not specified.

You can access index by ``path_to_output_dir/doc/index.html``
