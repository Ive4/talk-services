should = require 'should'
service = require '../../src/service'
{prepare, cleanup, req} = require '../util'
incoming = service.load 'incoming'

describe 'Incoming#Webhook', ->

  req.integration = _id: '123'

  it 'receive webhook', (done) ->
    incoming.sendMessage = (message) ->
      message.should.have.properties '_integrationId'
      message.quote.should.have.properties 'authorName', 'title', 'text', 'redirectUrl', 'thumbnailPicUrl', 'originalPicUrl'

    req.body =
      authorName: '路人甲'
      title: '你好'
      text: '天气不错'
      redirectUrl: 'https://talk.ai/site'
      imageUrl: 'https://dn-talk.oss.aliyuncs.com/site/images/workspace-84060cfd.jpg'

    incoming.receiveEvent 'service.webhook', req
    .then -> done()
    .catch done