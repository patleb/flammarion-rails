# https://stackoverflow.com/questions/2238030/trigger-document-ready-so-ajax-code-i-cant-modify-is-executed#answer-8125920
window.readyList = []

# Store a reference to the original ready method.
window.originalReadyMethod = $.fn.ready

# Override jQuery.fn.ready
$.fn.ready = ->
  if arguments.length && arguments.length > 0 && typeof arguments[0] == 'function'
    window.readyList.push(arguments[0])

  # Execute the original method.
  window.originalReadyMethod.apply(this, arguments)

# Used to trigger all ready events
$.triggerReady = ->
  $(window.readyList).each(-> this())
