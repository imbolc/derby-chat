derby = require 'derby'
moment = require 'moment'
app = derby.createApp(module)
  .use(require '../../ui')

favicon = null

focusEnter = ->
  el = document.getElementById 'enter'
  el.focus()

scrollDown = ->
  el = document.getElementById 'chat'
  el.scrollTop = el.scrollHeight

filterMessages = (model, threadId) ->
  if threadId
    filterFn = (message) ->
      message.threadId is threadId
    model.filter('messages', filterFn).ref '_page.messages'
  else
    model.filter('messages').ref '_page.messages'

app.get '/', (page, model) ->
  userId = model.get '_session.userId'
  user = model.at 'users.' + userId

  model.subscribe 'threads', 'users', 'messages', (err) ->
    return next(err) if err

    model.filter('threads').ref '_page.threads'
    model.ref '_page.user', user
    if not model.get '_page.user.id'
      model.set '_page.user.id', userId
    model.filter('users').ref '_page.users'
    filterMessages model
    page.render()

app.enter '/', (model) ->
  isActive = true
  badge = 0
  window.onfocus = ->
    isActive = true
    badge = 0
    favicon.reset()
  window.onblur = ->
    isActive = false
  focusEnter()
  scrollDown()
  model.on 'change', 'messages**', ->
    scrollDown()
    if not isActive
      badge++
      favicon.badge badge
  favicon = new Favico {animation: 'popFade'}


app.fn 'message.add', (e, el) ->
  if e.keyCode is 13
    e.preventDefault()
    text = @model.del '_page.text'

    if text
      message =
        text: text
        userId: @model.get '_session.userId'

      threadId = @model.get '_page.threadId'
      if not threadId
        answerMessageId = @model.get '_page.answerMessageId'
        if answerMessageId
          answerMessage = @model.get 'messages.' + answerMessageId
          if answerMessage.threadId
            threadId = answerMessage.threadId
          else
            thread =
              name: answerMessage.text
              color: '#'+(0x1000000+(Math.random())*0xffffff).toString(16).substr(1,6)

            threadId = @model.add 'threads', thread
            @model.set 'messages.' + answerMessageId + '.threadId', threadId

      message.threadId = threadId
      @model.add 'messages', message
      @model.del '_page.answerMessageId'


app.fn 'thread.add', (e, el) ->
  message = @model.at(el).get()

  @model.set '_page.answerMessageId', message.id

  focusEnter()

app.fn 'thread.edit', (e, el) ->
  threadId = el.getAttribute 'data-id'
  @model.set '_page.editThreadId', threadId

app.fn 'thread.save', (e, el) ->
  @model.del '_page.editThreadId'

app.fn 'thread.all', (e, el) ->
  filterMessages @model
  @model.del '_page.threadId'
  focusEnter()
  scrollDown()

app.fn 'thread.select', (e, el) ->
  threadId = el.getAttribute 'data-id'
  filterMessages @model, threadId
  @model.set '_page.threadId', threadId
  focusEnter()
  scrollDown()

app.fn 'thread.reset', (e, el) ->
  @model.del '_page.answerMessageId'

app.view.fn 'color', (threadId) ->
  thread = @model.get 'threads.' + threadId
  thread?.color or 'black'

app.view.fn 'name', (userId) ->
  name = @model.get 'users.' + userId + '.name'
  name or 'Anonymous'

app.view.fn 'thread', (threadId) ->
  thread = @model.get 'threads.' + threadId
  if thread and thread.name
    if thread.name.length > 20
      return thread.name.substr(0, 19) + '..'
    return thread.name
  ''

app.view.fn 'writing', (threadId, answerMessageId) ->
  if answerMessageId
    message = @model.get 'messages.' + answerMessageId
    if message.threadId
      threadId = message.threadId
    else
      return 'New Discussion from message: ' + message.text

  if threadId
    thread = @model.get 'threads.' + threadId
    if thread
      return thread.name

  'General Chat'