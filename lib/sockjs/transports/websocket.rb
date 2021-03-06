# encoding: utf-8

require "forwardable"
require "sockjs/faye"
require "sockjs/transport"

# Raw WebSocket url: /websocket
# -------------------------------
#
# SockJS protocol defines a bit of higher level framing. This is okay
# when the browser using SockJS-client establishes the connection, but
# it's not really appropriate when the connection is being established
# from another program. Although SockJS focuses on server-browser
# communication, it should be straightforward to connect to SockJS
# from command line or some any programming language.
#
# In order to make writing command-line clients easier, we define this
# `/websocket` entry point. This entry point is special and doesn't
# use any additional custom framing, no open frame, no
# heartbeats. Only raw WebSocket protocol.

module SockJS
  module Transports
    module WSDebuggingMixin
      def send_data(*args)
        if args.length == 1
          data = args.first
        else
          data = fix_buggy_input(*args)
        end

        SockJS.debug "WS#send #{data.inspect}"

        super(data)
      end

      def fix_buggy_input(*args)
        data = 'c[3000,"Go away!"]'
        SockJS.debug "[ERROR] Incorrect input: #{args.inspect}, changing to #{data} for now"
        return data
      end

      def close(*args)
        SockJS.debug "WS#close(#{args.inspect[1..-2]})"
        super(*args)
      end
    end

    class WebSocket < ConsumingTransport
      register 'GET', 'websocket'

      def disabled?
        !options[:websocket]
      end

      def session_key(ws)
        ws.object_id.to_s
      end

      def handle_request(request)
        if not @options[:websocket]
          raise HttpError.new(404, "WebSockets Are Disabled")
        elsif request.env["HTTP_UPGRADE"].to_s.downcase != "websocket"
          raise HttpError.new(400, 'Can "Upgrade" only to "WebSocket".')
        elsif not ["Upgrade", "keep-alive, Upgrade"].include?(request.env["HTTP_CONNECTION"])
          raise HttpError.new(400, '"Connection" must be "Upgrade".')
        end

        super
      end

      def build_response(request)
        SockJS.debug "Upgrading to WebSockets ..."

        web_socket = Faye::WebSocket.new(request.env)

        web_socket.extend(WSDebuggingMixin)

        return web_socket
      end

      def build_error_response(request)
        response = response_class.new(request)
      end

      def process_session(session, web_socket)
        #XXX Facade around websocket?

        web_socket.onopen = lambda do |event|
          begin
            session.attach_consumer(web_socket, self)
          rescue Object => ex
            SockJS::debug "Error opening (#{event.inspect[0..40]}) websocket: #{ex.inspect}"
          end
        end

        web_socket.onmessage = lambda do |event|
          begin
            session.receive_message(extract_message(event))
          rescue Object => ex
            SockJS::debug "Error receiving message on websocket (#{event.inspect[0..40]}): #{ex.inspect}"
            web_socket.close
          end
        end

        web_socket.onclose = lambda do |event|
          begin
            session.close
          rescue Object => ex
            SockJS::debug "Error closing websocket (#{event.inspect[0..40]}): #{ex.inspect}"
          end
        end
      end

      def format_frame(response, frame)
        frame.to_s
      end

      def send_data(web_socket, data)
        web_socket.send(data)
        return data.length
      end

      def finish_response(web_socket)
        web_socket.close
      end

      def extract_message(event)
        SockJS.debug "Received message event: #{event.data.inspect}"
        event.data
      end
    end

    class RawWebSocket < WebSocket
      register 'GET', 'websocket'

      def self.routing_prefix
        "/" + self.prefix
      end

      def opening_frame(response)
      end

      def heartbeat_frame(response)
      end

      def extract_message(event)
        SockJS.debug "Received message event: #{event.data.inspect}"
        MultiJson.dump(event.data)
      end

      def messages_frame(websocket, messages)
        messages.inject(0) do |sent_count, data|
          send_data(websocket, data)
          sent_count + data.length
        end
      rescue Object => ex
        SockJS::debug "Error delivering messages to raw websocket: #{messages.inspect} #{ex.inspect}"
      end

      def closing_frame(response, status, message)
        finish_response(response)
      end
    end
  end
end
