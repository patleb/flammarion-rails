# Disable Back/Forward
########################################

history.pushState(null, null, document.URL)
window.addEventListener 'popstate', ->
  history.pushState(null, null, document.URL)

# NProgress
########################################

if NProgress?
  window.progress_bar_timeout = null

  ws.send_before_actions.push (data) ->
    unless window.progress_bar_timeout?
      window.progress_bar_timeout = setTimeout(->
        NProgress.start()
      , 500)

  ws.onmessage_before_actions.push (event) ->
    NProgress.done()
    clearTimeout(window.progress_bar_timeout)
    window.progress_bar_timeout = null

# Pjax
########################################
# Note: it's working for now, but it might be better to do something similar to the real pjax implementation

if $.pjax?
  PROTOCOL = /^.*:\/{2}/i
  $(document).on 'pjax:beforeSend', (event, xhr, settings) ->
    event.preventDefault()
    ws.send(action: 'pjax', url: settings.url.replace(PROTOCOL, ''))

  ws.onmessage_actions.pjax = (event) ->
    new_page = $("<div>")
    new_page.html(ws_data.body)
    container = new_page.find('[data-pjax-container]')
    $('[data-pjax-container]').html(container.html())
    $(document).trigger('rails_admin.dom_ready')

# Submit
########################################

$(document).on 'submit', (event) ->
  event.preventDefault()
  form = $(event.target)
  return if form.hasClass('pjax-form')
  ws.send(action: 'submit', url: form.attr('action'), form: form.serialize(), button: document.activeElement.name)

ws.onmessage_actions.submit =
  if $.pjax?
    ws.onmessage_actions.pjax
  else
    ws.onmessage_actions.page

# File
########################################

if saveAs?
  window.ws_file = null

  ws.onmessage_actions.file = (event) ->
    window.ws_file = ws_data.name
    document.title = 'Downloading...'

  ws.send_before_actions.unshift (data) ->
    if window.ws_file?
      ws.send_skip_action = true

  ws.onmessage_before_actions.unshift (event) ->
    if window.ws_file?
      saveAs(event.data, window.ws_file)
      document.title = window.ws_file
      window.ws_file = null
      ws.onmessage_skip_action = true

# Ajax
########################################
# Note: app specific, $.ajax must be overriden
# Ex.:
# window.ajax_handler = $.ajax
#
# $.ajax = (xhr) ->
#   if xhr.type?
#     return ws.ajax_handler(xhr)
#
#   switch xhr.dataType
#     when 'text'
#       modal = $('#modal').data('ra-remoteForm')
#       ...
#     when 'json'
#       ...
#     else
#       ...
