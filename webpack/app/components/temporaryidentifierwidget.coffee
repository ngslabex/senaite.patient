import $ from "jquery"


class TemporaryIdentifierWidgetController

  constructor: ->
    console.debug "TemporaryIdentifierWidget::load"

    @auto_wildcard = "-- autogenerated --"
    @is_add_sample_form = document.body.classList.contains "template-ar_add"

    # reset all values from identifier widgets that are temporary if current
    # page is Add Sample form. Maybe the user selected samples from samples
    # listing and pressed "Copy to new", so the widget contains the values from
    # the original samples being copied, which is wrong
    if @is_add_sample_form
      @reset_values()

    # bind the event handler to the elements
    @bind_event_handler()
    return @

  ###
  Reset value_auto from all identifier widgets and value from identifier widgets
  that are temporary
  ###
  reset_values: =>
    @debug "°°° TemporaryIdentifierWidget::reset_values"

    # value elements (only if temporary is set)
    selector = ".TemporaryIdentifier.temporary-id input[id$='_value']"
    @reset_value el, @auto_wildcard for el in document.querySelectorAll(selector)

    selector = ".TemporaryIdentifier.temporary-id input[name*='.value:']"
    @reset_value el, @auto_wildcard for el in document.querySelectorAll(selector)

    # value_auto elements
    selector = ".TemporaryIdentifier input[name*='.value_auto:']"
    @reset_value el for el in document.querySelectorAll(selector)

  ###
  Reset the value for the given element
  ###
  reset_value: (el, value="") =>
    @debug "°°° TemporaryIdentifierWidget::reset_value:el=#{ el.id or el.name },value='#{ value }'"
    el.value = value

  bind_event_handler: =>
    @debug "TemporaryIdentifierWidget::bind_event_handler"
    $("body").on "change", ".TemporaryIdentifier input[type='checkbox']", @on_temporary_change
    $("body").on "change", ".TemporaryIdentifier input[type='text']", @on_value_change

  ###
  Event handler for TemporaryIdentifier's checkbox change
  ###
  on_temporary_change: (event) =>
    @debug "°°° TemporaryIdentifierWidget::on_temporary_change °°°"

    el = event.currentTarget
    field = @get_field_name el

    # Is temporary?
    is_temporary = el.checked

    # Update the hidden field that stores whether is temporary or not
    @set_temporary field, is_temporary

    # Get the value from the hidden field that stores the value autogenerated
    # by the system for this content in the past, if any. Otherwise, assume this
    # is either a new content or it was not temporary in the past by assigning
    # the wildcard "-- autogenerated --"
    auto = @get_autogenerated_id field, @auto_wildcard

    # Disable/enable the input field for manual introduction of value
    input_field = @get_input_element field
    input_field.disabled = is_temporary

    if is_temporary and not input_field.value
      # Update the value with autogenerated, but only if empty
      input_field.value = auto
      $(input_field).trigger "change"

    else if not is_temporary and input_field.value == auto
      # Clear the value, but only if autogenerated
      input_field.value = ""
      $(input_field).trigger "change"

  ###
  Event handler for TemporaryIdentifier's value change
  ###
  on_value_change: (event) =>
    @debug "°°° TemporaryIdentifierWidget::on_value_change °°°"

    el = event.currentTarget
    field = @get_field_name el

    # Get the current value
    current_value =  @get_current_id field

    # Update the hidden field that stores the id
    @set_current_id field, el.value

    # Do not continue unless the value is non-empty
    return unless el.value and el.value != @auto_wildcard

    # Search for an existing MRN
    @search_mrn el.value
    .done (data) ->
      return unless data

      # map patient fields -> Sample fields
      record = {
        "PatientFullName": data.Title,
        "PatientAddress": data.country,
        "DateOfBirth": @format_date( data.birthdate),
        "Age": data.age,
        "Gender": data.gender,
      }

      # Render the popup dialog
      me = @
      data.identifier ?= el.value
      dialog = @template_dialog "existing-identifier", data
      dialog.on "yes", ->
        # Update field values from the whole form
        for field, value of record
          me.set_sibling_value el, field, value

      dialog.on "no", ->
        # Restore the value and do nothing else
        el.value = current_value
        me.set_current_id field, current_value

  ###
  Sets the temporary value of te field
  ###
  set_temporary: (field, is_temporary) =>
    @get_subfield(field, "temporary").value = is_temporary or ""

  ###
  Sets the current id value of the field
  ###
  set_current_id: (field, value) =>
    @get_subfield(field, "value").value = value

  ###
  Returns the current id value of the field
  ###
  get_current_id: (field, default_value="") =>
    @get_subfield(field, "value").value or default_value

  ###
  Returns the id value that is/was auto-generated for the field
  ###
  get_autogenerated_id: (field, default_value="") =>
    @get_subfield(field, "value_auto").value or default_value

  ###
  Returns the input element for manual introduction of an identifier value
  ###
  get_input_element: (field) =>
    document.querySelector("##{ field }_value")

  ###
  Returns the field name the element belongs to
  ###
  get_field_name: (element) =>
    parent = element.closest("div[data-fieldname]")
    $(parent).attr "data-fieldname"

  ###
  Returns the sibling field element with the specified name
  ###
  get_sibling: (element, name) =>
    field = name
    if @is_add_sample_form
      parent = element.closest("td[arnum]")
      sample_num = $(parent).attr "arnum"
      field = name+'-'+sample_num
    document.querySelector('[name="'+field+'"]')

  ###
  Sets the value for an sibling field with specified base name
  ###
  set_sibling_value: (element, name, value) =>
    @debug "°°° TemporaryIdentifierWidget::set_sibling_value:name=#{ name },value=#{ value } °°°"
    field = @get_sibling element, name
    return unless field
    @debug ">>> #{ field.name } = #{ value } "
    field.value = value

  ###
  Formats a date to yyyy-mm-dd
  ###
  format_date: (date_value) =>
    if not date_value?
      return ""
    d = new Date(date_value)
    out = [
      d.getFullYear(),
      ('0' + (d.getMonth() + 1)).slice(-2),
      ('0' + d.getDate()).slice(-2),
    ]
    out.join('-')

  get_subfield: (field, subfield) =>
    document.querySelector 'input[name^="'+field+'.'+subfield+':"]'

  ###
  Searches by medical record number. Returns a dict with information about the
  patient if the mrn is found. Returns nothing otherwise
  ###
  search_mrn: (mrn) =>
    @debug "°°° TemporaryIdentifierWidget::search_mrn:mrn=#{ mrn } °°°"

    # Fields to include on search results
    fields = [
      "Title"
      "name"
      "surname"
      "age"
      "birthdate"
      "gender"
      "email"
      "address"
      "zipcode"
      "city"
      "country"
    ]

    deferred = $.Deferred()
    options =
      url: @get_portal_url() + "/@@API/read"
      data:
        portal_type: "Patient"
        catalog_name: "portal_catalog"
        patient_mrn: mrn
        include_fields: fields
        page_size: 1

    @ajax_submit options
    .done (data) ->
      object = {}
      if data.objects
        # resolve with the first item of the list
        object = data.objects[0]
      return deferred.resolveWith this, [object]

    deferred.promise()

  ###
  Render the content of a Handlebars template in a jQuery UID dialog
  [1] http://handlebarsjs.com/
  [2] https://jqueryui.com/dialog/
  ###
  template_dialog: (template_id, context, buttons) =>
    # prepare the buttons
    if not buttons?
      buttons = {}
      buttons[_t("Yes")] = ->
        # trigger 'yes' event
        $(@).trigger "yes"
        $(@).dialog "close"
      buttons[_t("No")] = ->
        # trigger 'no' event
        $(@).trigger "no"
        $(@).dialog "close"

    # render the Handlebars template
    content = @render_template template_id, context

    # render the dialog box
    $(content).dialog
      width: 450
      resizable: no
      closeOnEscape: no
      buttons: buttons
      open: (event, ui) ->
        # Hide the X button on the top right border
        $(".ui-dialog-titlebar-close").hide()

  render_template: (template_id, context) =>
    ###
     * Render Handlebars JS template
    ###
    @debug "°°° TemporaryIdentifierWidget::render_template:template_id:#{ template_id } °°°"

    # get the template by ID
    source = $("##{template_id}").html()
    return unless source
    # Compile the handlebars template
    template = Handlebars.compile(source)
    # Render the template with the given context
    template(context)

  ###
  Ajax Submit with automatic event triggering and some sane defaults
  ###
  ajax_submit: (options={}) =>
    @debug "°°° TemporaryIdentifierWidget::ajax_submit °°°"

    # some sane option defaults
    options.type ?= "POST"
    options.url ?= @get_portal_url()
    options.context ?= this
    options.dataType ?= "json"
    options.data ?= {}
    options._authenticator ?= $("input[name='_authenticator']").val()

    console.debug ">>> ajax_submit::options=", options

    $(this).trigger "ajax:submit:start"
    done = ->
      $(this).trigger "ajax:submit:end"
    return $.ajax(options).done done

  ###
  Returns the portal url (calculated in code)
  ###
  get_portal_url: =>
    url = $("input[name=portal_url]").val()
    return url or window.portal_url

  ###
  Prints a debug message in console with this component name prefixed
  ###
  debug: (message) =>
    console.debug "[senaite.patient.temporary_identifier_widget] ", message

export default TemporaryIdentifierWidgetController
