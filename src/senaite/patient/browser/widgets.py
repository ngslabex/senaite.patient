# -*- coding: utf-8 -*-
#
# This file is part of SENAITE.PATIENT.
#
# SENAITE.PATIENT is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, version 2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51
# Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Copyright 2020-2022 by it's authors.
# Some rights reserved, see README and LICENSE.

import six
from AccessControl import ClassSecurityInfo
from bika.lims import api
from bika.lims.idserver import generateUniqueId
from Products.Archetypes.Registry import registerWidget
from Products.Archetypes.Widget import StringWidget
from Products.Archetypes.Widget import TypesWidget
from senaite.core.browser.widgets import DateTimeWidget
from senaite.patient import api as patient_api
from senaite.patient.config import AUTO_ID_MARKER


class TemporaryIdentifierWidget(TypesWidget):
    """A widget for the introduction of temporary IDs (e.g. MRN). It displays
    an input text box for manual introduction of the ID, next to a "Temporary"
    checkbox. When the checkbox is selected, system assumes the ID is temporary
    and must be auto-generated.
    """
    security = ClassSecurityInfo()
    _properties = StringWidget._properties.copy()
    _properties.update({
        "macro": "senaite_patient_widgets/temporaryidentifierwidget",
    })

    def process_form(self, instance, field, form, empty_marker=None,
                     emptyReturnsMarker=False, validating=True):

        value = form.get(field.getName())

        # Allow non-required fields
        if not value:
            return None, {}

        # Is this Identifier temporary?
        true_values = ("true", "1", "on", "True", True, 1)
        temporary = value.get("temporary", False) in true_values

        # The ID might need to be auto-generated if temporary?
        autogenerated = value.get("autogenerated", "")
        identifier = value.get("value") or None
        if temporary and identifier in [None, AUTO_ID_MARKER]:
            kwargs = {"portal_type": field.getName()}
            identifier = generateUniqueId(api.get_portal(), **kwargs)
            autogenerated = identifier

        value = {
            "temporary": temporary,
            "value": identifier,
            "value_auto": autogenerated,
        }
        return value, {}


class AgeDoBWidget(DateTimeWidget):
    """A widget for the introduction of Age and/or Date of Birth.
    When Age is introduced, the Date of Birth is calculated automatically.
    """
    security = ClassSecurityInfo()
    _properties = DateTimeWidget._properties.copy()
    _properties.update({
        "show_time": False,
        "default_age": False,
        "macro": "senaite_patient_widgets/agedobwidget",
    })

    def get_age_selected(self, context):
        name = self.getName()
        attr = "_%s_age_selected" % name
        return getattr(context, attr, False)

    def set_age_selected(self, context, value):
        name = self.getName()
        attr = "_%s_age_selected" % name
        setattr(context, attr, bool(value))

    def get_current_age(self, dob):
        """Returns a dict with keys "years", "months", "days"
        """
        if not api.is_date(dob):
            return {}

        delta = patient_api.get_relative_delta(dob)
        return {
            "years": delta.years,
            "months": delta.months,
            "days": delta.days,
        }

    def process_form(self, instance, field, form, empty_marker=None,
                     emptyReturnsMarker=False, validating=True):

        value = form.get(field.getName())

        # Not interested in the hidden field, but in the age + dob specific
        if isinstance(value, (list, tuple)):
            value = value[0] or None

        # Allow non-required fields
        if not value:
            return None, {}

        # handle DateTime object when creating partitions
        if api.is_date(value):
            self.set_age_selected(instance, False)
            return value, {}

        # Grab the input for DoB first
        dob = value.get("dob", "")
        dob = patient_api.to_datetime(dob)
        age_selected = value.get("selector") == "age"

        # remember what was slected
        self.set_age_selected(instance, age_selected)

        # Maybe user entered age instead of DoB
        if age_selected:
            # Validate the age entered
            ymd = map(lambda p: value.get(p), ["years", "months", "days"])
            if not any(ymd):
                # No values set
                return None

            # Age in ymd format
            ymd = filter(lambda p: p[0], zip(ymd, 'ymd'))
            ymd = "".join(map(lambda p: "".join(p), ymd))

            # Calculate the DoB
            dob = patient_api.get_birth_date(ymd)

        return dob, {}


class FullnameWidget(TypesWidget):
    """A widget for the introduction of person name, either fullname or the
    combination of firstname + lastname
    """
    security = ClassSecurityInfo()
    _properties = TypesWidget._properties.copy()
    _properties.update({
        "macro": "senaite_patient_widgets/fullnamewidget",
        "entry_mode": "parts",
        "view_format": "%(firstname)s %(lastname)s",
        "size": "15",
    })

    def process_form(self, instance, field, form, empty_marker=None,
                     emptyReturnsMarker=False, validating=True):

        value = form.get(field.getName())
        firstname = ""
        lastname = ""

        if isinstance(value, (list, tuple)):
            value = value[0] or None

        # handle string as fullname direct entry
        if isinstance(value, six.string_types):
            firstname = value.strip()

        elif value:
            firstname = value.get("firstname", "").strip()
            lastname = value.get("lastname", "").strip()

        # Allow non-required fields
        if not any([firstname, lastname]):
            return None, {}

        output = {
            "firstname": firstname,
            "lastname": lastname,
        }
        return output, {}


# Register widgets
registerWidget(TemporaryIdentifierWidget, title="TemporaryIdentifierWidget")
registerWidget(AgeDoBWidget, title="AgeDoBWidget")
registerWidget(FullnameWidget, title="FullnameWidget")
