{{ opts['cachedir'] }}/salt-raven-requirements.txt:
  file:
    - absent

raven:
  pip:
    - removed
