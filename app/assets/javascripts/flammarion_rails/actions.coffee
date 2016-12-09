# NProgress

window.progress_bar_timeout = null

ws.send_before_actions.push (data) ->
  if NProgress?
    unless window.progress_bar_timeout?
      window.progress_bar_timeout = setTimeout(->
        NProgress.start()
      , 500)

ws.onmessage_before_actions.push (event) ->
  if NProgress?
    NProgress.done()
    clearTimeout(window.progress_bar_timeout)
    window.progress_bar_timeout = null

# Error

ws.onmessage_actions.error = (event) ->
  document.title = ws_data.title

# Pjax

$(document).on 'pjax:beforeSend', (event, xhr, settings) ->
  event.preventDefault()
  ws.send(action: 'pjax', url: settings.url.replace(/^.*:\/{2}/i, ''))

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
  return if form.hasClass 'pjax-form'
  button_name = document.activeElement.name
  ws.send(action: 'submit', url: form.attr('action'), method: 'post', form: form.serialize(), "#{button_name}": '')

ws.onmessage_actions.submit = ws.onmessage_actions.pjax
