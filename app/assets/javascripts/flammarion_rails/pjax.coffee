window.progress_bar_timeout = null

ws.send_actions.pjax ||= (data) ->
  if NProgress?
    window.progress_bar_timeout = setTimeout(->
      NProgress.start()
    , 500)

ws.onmessage_actions.pjax ||= (event) ->
  new_page = $("<div>")
  new_page.html(ws_data.html)
  container = new_page.find('[data-pjax-container]')
  $('[data-pjax-container]').html(container.html())
  if NProgress?
    NProgress.done()
    clearTimeout(window.progress_bar_timeout)
  $(document).trigger('rails_admin.dom_ready')
