# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class XHRPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :xhr_poll]

      # Handler.
      def handle(env)
        match = env["PATH_INFO"].match(self.class.prefix)
        puts "\033[0;34;40m? SESSION #{match[1]} = #{connection.sessions[match[1]].inspect}\033[0m"

        if session = self.connection.sessions[match[1]]
          body = session.process_buffer

          unless body.respond_to?(:bytesize)
            raise TypeError, "Block has to return a string or a string-like object responding to #bytesize, but instead an object of #{body.class} class has been returned (object: #{body.inspect})."
          end

          [200, {"Content-Type" => "text/plain", "Content-Length" => body.bytesize.to_s}, [body]]
        else
          begin
            session = self.connection.create_session(match[1])
            body = session.open!
          rescue SockJS::CloseError => error
            body = Protocol.close_frame(error.status, error.message)
          end
          [200, {"Content-Type" => "text/plain", "Content-Length" => body.bytesize.to_s}, [body]]
        end
      end
    end

    class XHROptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def handle(env)
        [204, {"Allow" => "OPTIONS, POST", "Access-Control-Max-Age" => "1"}, Array.new]
      end
    end

    class XHRSendPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :expect_xhr, :xhr_send]

      # Handler.
      def handle(env)
        match = env["PATH_INFO"].match(self.class.prefix)
        session_id = match[1]
        session = self.connection.sessions[session_id]
        if session
          session.receive_message(env["rack.input"].read)
          puts "\033[0;32;40m~~> SESSION #{session_id} = #{connection.sessions[session_id].inspect}\033[0m" ###
          [204, Hash.new, Array.new]
        else
          [500, Hash.new, ["Session is not open!"]]
        end
      end
    end

    class XHRSendOptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def handle(env)
        match = env["PATH_INFO"].match(self.class.prefix)
        p session_id = match[1]
        raise NotImplementedError.new
      end
    end

    class XHRStreamingPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :xhr_streaming]

      # Handler.
      def handle(env)
        raise NotImplementedError.new
      end
    end

    class XHRStreamingOptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def handle(env)
        raise NotImplementedError.new
      end
    end
  end
end
