# NProgress

window.progress_bar_timeout = null

ws.send_before_actions.push (data) ->
  if NProgress?
    window.progress_bar_timeout = setTimeout(->
      NProgress.start()
    , 500)

ws.onmessage_before_actions.push (event) ->
  if NProgress?
    NProgress.done()
    clearTimeout(window.progress_bar_timeout)

# Pjax

$(document).on 'pjax:beforeSend', (event, xhr, settings) ->
  event.preventDefault()
  ws.send(action: 'pjax', url: settings.url)

ws.onmessage_actions.pjax = (event) ->
  new_page = $("<div>")
  new_page.html(ws_data.html)
  container = new_page.find('[data-pjax-container]')
  $('[data-pjax-container]').html(container.html())
  $(document).trigger('rails_admin.dom_ready')

# Submit

$(document).on 'submit', (event) ->
  event.preventDefault()
  form = $(event.target)
  #TODO ws.send(action: 'submit', form: form.serialize())
