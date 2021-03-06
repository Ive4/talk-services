_ = require 'lodash'
Promise = require 'bluebird'
marked = require 'marked'
util = require '../util'

###*
 * Define handler when receive incoming webhook from gitlab
 * @param  {Object}   req      Express request object
 * @param  {Function} callback
 * @return {Promise}
###
_receiveWebhook = ({integration, body}) ->
  # The errors should be catched and transmit to callback
  self = this
  payload = body

  switch payload.object_kind
    when 'build' then payload.event = 'build'
    when 'issue' then payload.event = 'issues'
    when 'merge_request' then payload.event = 'merge_request'
    else payload.event = 'push'

  {repository, commits, object_attributes} = payload

  commits or= []

  message = {}
  attachment = category: 'quote', data: {}

  switch payload.event
    when 'push'
      attachment.data.title = "#{repository?.name}"
      if payload.before is '0000000000000000000000000000000000000000'
        attachment.data.title += " create branch #{payload.ref}"
      else if payload.after is '0000000000000000000000000000000000000000'
        attachment.data.title += " remove branch #{payload.ref}"
      else
        attachment.data.title += " new commits"
      commitArr = commits.map (commit) ->
        authorPrefix = if commit?.author?.name then " [#{commit.author.name}] " else " "
        """
        <a href="#{commit.url}" target="_blank"><code>#{commit?.id?[0...6]}:</code></a>#{authorPrefix}#{commit?.message}<br>
        """
      attachment.data.text = commitArr.join ''
      attachment.data.redirectUrl = repository?.homepage
    when 'merge_request'
      attachment.data.title = "[#{object_attributes?.state}] #{object_attributes?.title}"
      attachment.data.text = """
      #{marked(object_attributes?.description or '')}
      """
    when 'issues'
      attachment.data.title = "[#{object_attributes?.state}] #{object_attributes?.title}"
      attachment.data.text = """
      #{marked(object_attributes?.description or '')}
      """
    when 'build'
      # Gitlab API 更改了部分参数, 所以老的一些赋值方法可能失效
      {
        ref
        commit
        build_id
        build_name
        repository
        build_status
        project_name
        build_duration
      } = payload

      goodStatus = ['success', 'failed', 'canceled']
      return if build_status not in goodStatus

      color =
        switch build_status
          when goodStatus[0] then attachment.color = 'green'
          when goodStatus[1] then attachment.color = 'red'
          when goodStatus[2] then attachment.color = 'yellow'

      commitUrl = "#{repository.homepage}/commit/#{commit.sha}"

      text = """
        ref: #{ref}
        commit: [#{commit.sha[..7]}](#{commitUrl})
        author: #{commit.author_name}
        status: #{build_status}
        duration: #{Math.round build_duration}s
      """

      attachment.data =
        redirectUrl: commitUrl
        text: marked(text).trim()
        title: "Build: #{project_name}"

  lockKey = "lock:gitlab:#{integration._roomId}:#{integration._teamId}:#{integration._id}:#{payload.event}"

  ###*
   * @todo Find out the reason why gitlab will post same event and payload more than once
  ###
  return if util.isLocked lockKey
  util.lock lockKey, 20000
  message.attachments = [attachment]
  message

module.exports = ->
  @title = 'GitLab'

  @template = 'webhook'

  @summary = util.i18n
    zh: '用于仓库管理系统的开源项目。'
    en: 'GitLab is a web-based Git repository manager with wiki and issue tracking features.'

  @description = util.i18n
    zh: 'GitLab 是一个用于仓库管理系统的开源项目，添加后可以收到来自 GitLab 的推送。'
    en: 'GitLab is a software repository manager. You may connect webhooks of GitLab repos.'

  @iconUrl = util.static 'images/icons/gitlab@2x.png'

  @_fields.push
    key: 'webhookUrl'
    type: 'text'
    readOnly: true
    description: util.i18n
      zh: '复制 web hook 地址到你的 GitLab 仓库当中使用。你也可以在管理界面当中找到这个 web hook 地址。'
      en: 'Copy this web hook to your GitLab repo to use it. You may also find this url in the manager tab.'

  # Apply function on `webhook` event
  @registerEvent 'service.webhook', _receiveWebhook
