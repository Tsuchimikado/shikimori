# frozen_string_literal: true

class Topic::Create
  method_object %i[params! locale! faye!]

  def call
    topic = build_topic

    if @faye.create topic
      broadcast topic if broadcast? topic
    end

    topic
  end

private

  def build_topic
    Topic.new @params.merge(locale: @locale)
  end

  def broadcast? topic
    Topic::BroadcastPolicy.new(topic).required?
  end

  def broadcast topic
    Notifications::BroadcastTopic.perform_in 10.seconds, topic.id
  end
end
