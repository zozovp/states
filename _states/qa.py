# -*- coding: utf-8 -*-
import copy
import os
import logging
import re

__virtualname__ = 'qa'

logger = logging.getLogger(__name__)


def __virtual__():
    if 'qa.parse_doctrees' not in __salt__:
        logger.warning("Can't load state '%s' module is not available.",
                       __virtualname__)
        return False
    return __virtualname__


def _iter_to_bullet_list(iterable):
    output = ""
    for item in iterable:
        output += "- %s%s" % (item, os.linesep)
    return output


def _comment(iterable, message, comments):
    # if there is no error to append to comments, just skip it
    if iterable:
        header = '-' * 10
        comments.append(
            os.linesep.join((
                message % len(iterable),
                header,
                _iter_to_bullet_list(iterable)
            ))
        )


_key_re = re.compile(r'{{ ([\w\-\_\.]+) }}')
def _contains(iterable, elem):
    """
    Returns whether an element matches any of an iterable
    of "template" names (such as `foo:{{ id }}:bar`)
    """
    sub_key = r"([\w\-\_\.]+)"
    key_list = []
    for key in iterable:
        # transform {{ xxx }} into ([\w\d_]+)
        key_re = r"^({})$".format(_key_re.sub(sub_key, key))
        logger.debug("regex to compare: %r(%s)", key_re, key_re)
        if re.match(key_re, elem):
            return key

        #print "sub", key, _key_re.pattern, sub_key
        #key_list.append(key_re)
        #print "res", key_list[-1]
        #print

    #compare_re = re.compile("({})".format(
    #    "|".join("({})".format(k) for k in key_list)))
    #return bool(compare_re.match(elem)), compare_re.pattern
    return ""

def _matches(iterable, template):
    """
    Returns whether any element of an iterable of strings matches
    a given "template" string, as defined in `_contains`
    """
    for elem in iterable:
        if _contains([template], elem):
            return elem
    return ''

def test_pillar(name, pillar_doc):
    """
    Test pillar documentation for the given formula

    :param name: The name of the formula to test
    :param pillar_doc: Absolute path to the doc build output directory
    """
    ret = {'name': name,
           'changes': {},
           'result': True,
           'comment': ""}

    if not __salt__['pillar.get']("__test__", False):
        ret['comment'] = "Skipping test because __test__ = False"
        return ret

    doctrees = __salt__['qa.parse_doctrees'](pillar_doc)
    calls = __salt__['pillar.get_calls']()
    all_accessed = calls.keys()

    #: this is all keys: mandatory, optional and conditional
    all_documented = []
    all_mandatory = []
    for pillar, data in doctrees.iteritems():
        if isinstance(data, dict):
            all_documented.extend(data.get('optional', {}).keys())
            all_documented.extend(data.get('conditional', {}).keys())
            mandatory = data.get('mandatory', {})
            mandatory_keys = mandatory.get('keys', [])
            all_mandatory.extend(mandatory_keys)
            all_documented.extend(mandatory_keys)

    # list of pillar keys that had been used during rendering
    # and if any had been undocumented
    undocumented = []
    for key in all_accessed:
        if not _contains(all_documented, key):
            undocumented.append(key)

    # list of all documented pillars keys but that had not been used
    if all_accessed:
        try:
            documented = [key for key in doctrees[name]['optional']]
        except KeyError:
            documented = []
        unused = []
        for key in documented:
            if not _matches(all_accessed, key):
                unused.append(key)
    else:
        unused = []

    # pillar key usage that have different default values
    multiple_defaults = set(filter(lambda x: len(calls[x]) > 1, calls))

    bad_mandatory_calls = []
    # check that no mandatory keys have been called with defaults
    #for key in doctrees[name]['mandatory']['keys']:
    for key, kcalls in calls.iteritems():
        if not _contains(doctrees[name]['mandatory']['keys'],
                         key):
            continue
        kcalls = copy.copy(kcalls)
        if len(kcalls) > 1:
            bad_mandatory_calls.append("{}: multiple calls: ({})".format(
                key, list(calls[key])))
        elif len(kcalls) < 1:
            bad_mandatory_calls.append("{}: {}".format(key, "Not used"))
        else:
            default = kcalls.pop()
            # NOTE: this is coupled with the custom pillar module.
            if default is not KeyError:
                bad_mandatory_calls.append("{}: called with default: {}".format(
                    key, default))


    # pillar key usage that have default values different to the one documented
    bad_defaults = set()
    #for key in doctrees[name]['optional']:
    for key, kcall in calls.iteritems():
        # I don't report keys already reported as multiple defaults or that's
        #  not in the docs
        if (key not in multiple_defaults and
            key not in undocumented and
            key not in unused and
            _contains(doctrees[name]['optional'], key)):
            doc_default = doctrees[name]['optional'][key]['default']
            kcall = copy.copy(kcall)
            if len(kcall) > 1:
                bad_defaults.add("%s: should be in multiple defaults" % key)
                continue
            elif len(kcall) < 1:
                bad_defaults.add("%s: should be in unused" % key)
                continue
            use_default = kcall.pop()
            if use_default != doc_default:
                bad_defaults.add("%s: (doc: %r|use: %r)" % (key,
                                                            doc_default,
                                                            use_default))

    # other kind of errors
    errors = []
    try:
        ddata = doctrees[name]
    except KeyError:
        ret['comment'] = "No pillar doc for formula '%s'" % name
        ret['result'] = False
        return ret

    for key, kdata in ddata.get('optional', {}).iteritems():
        for error in kdata['_errors']:
            errors.append("%s %s: %s" % (name, key, error))
    for key, kdata in ddata.get('conditional', {}).iteritems():
        for error in kdata['_errors']:
            errors.append("%s %s: %s" % (name, key, error))

    if not undocumented and not unused and not multiple_defaults and \
            not bad_mandatory_calls and not bad_defaults and not errors:
        ret['comment'] += "Formula '%s' and requirements are OK." % name
    else:
        ret['result'] = False
        comments = []
        _comment(sorted(undocumented), "%d undocumented pillars", comments)
        _comment(sorted(unused), "%d unused documented pillars", comments)
        _comment(sorted(bad_mandatory_calls), "%d mandatory pillars used with defaults",
                 comments)
        _comment(sorted(multiple_defaults), "%d pillars with different default value calls",
                 comments)
        _comment(sorted(bad_defaults), ("%d pillars with defaults different than "
                                "documented"), comments)
        _comment(errors, "%d errors", comments)

        # extra debug output
        _comment(sorted(all_documented), "%d total documented pillars", comments)
        _comment(sorted(__salt__['pillar.get_call_desc']()), "%d calls", comments)

        ret['comment'] = os.linesep.join(comments)
    __salt__['pillar.reset']()
    return ret


def test_monitor(name, pillar_doc, additional=()):
    '''
    Test monitor documentation for the given formula

    .. note:: Sometimes it needs `$formula` and `$formula.backup` to have all
              checks

    :param name: The name of the formula to test
    :param pillar_doc: Absolute path to the doc build output directory
    :param additional: Additional formulas to test
    '''
    formulas = [name]
    formulas.extend(additional)

    ret = {'name': 'test_monitor',
           'changes': {},
           'result': True,
           'comment': "Formula(s) '%s' checks." % ','.join(formulas)}

    # build list of all monitoring check name for formula(s)
    check_names = []
    yml_invalids = []
    for formula in formulas:
        checks = __salt__['monitoring.load_check'](formula)
        if not checks:
            yml_invalids.append(formula)
        else:
            check_names.extend(checks.keys())
    check_names = set(check_names)

    if yml_invalids:
        ret['comment'] = "%d invalid or missing yml files: %s%s" % (
            len(yml_invalids), os.linesep, os.linesep.join(yml_invalids)
        )
        ret['result'] = False
        return ret

    logger.debug("Found %d for all %d formulas: %s", len(check_names),
                 len(formulas), ','.join(check_names))

    doctrees = __salt__['qa.parse_doctrees'](pillar_doc)

    # extract documented check names and errors
    doc_names = []
    mandatory_doc_names = []
    doc_errors = []
    for name, data in doctrees.iteritems():
        if name in formulas:
            doc_names.extend(data['_monitor']['mandatory'])
            mandatory_doc_names.extend(data['_monitor']['mandatory'])
            doc_names.extend(data['_monitor']['optional'])
        for error in data['_monitor']['_errors']:
            doc_errors.append("%s: %s" % (name, error))
    doc_names = set(doc_names)
    mandatory_doc_names = set(mandatory_doc_names)

    logger.debug("Documented checks: %s", ','.join(doc_names))

    not_documented = []
    for name in check_names:
        if not _contains(doc_names, name):
            not_documented.append(name)
    not_present = []
    for name in mandatory_doc_names:
        if not _matches(check_names, name):
            not_present.append(name)

    if not not_documented and not not_present and not doc_errors:
        ret['comment'] += 'are OK.'
    else:
        ret['result'] = False
        comments = []
        _comment(not_documented, "%d undocumented checks", comments)
        _comment(not_present, "%d documented unused checks", comments)
        _comment(doc_errors, "%d document errors", comments)

        # extra debug output
        _comment(doc_names, "%d total documented checks", comments)
        _comment(check_names, "%d total present checks", comments)

        ret['comment'] = os.linesep.join(comments)
    return ret


def test(name, pillar_doc, additional=()):
    """
    Test both pillars and monitoring documentation for the given formula

    :param name: The name of the formula to test
    :param pillar_doc: Absolute path to the doc build output directory
    :param additional: Additional formulas to test
    """
    pillar = test_pillar(name, pillar_doc)
    monitor = test_monitor(name, pillar_doc, additional=additional)
    ret = {'name': name,
           'changes': {},
           'result': pillar['result'],
           'comment': ""}
    if not pillar['result']:
        ret['comment'] = os.linesep.join(("Pillar", "=" * 6,
                                          pillar['comment']))
    if not pillar['result'] and not monitor['result']:
        ret['comment'] += os.linesep
    if not monitor['result']:
        ret['comment'] += os.linesep.join(("Monitor", "=" * 7,
                                          monitor['comment']))
    return ret
