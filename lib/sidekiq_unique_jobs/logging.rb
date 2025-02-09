# frozen_string_literal: true

module SidekiqUniqueJobs
  # Utility module for reducing the number of uses of logger.
  #
  # @author Mikael Henriksson <mikael@zoolutions.se>
  module Logging
    def self.included(base)
      base.send(:extend, self)
    end

    # A convenience method for using the configured logger
    def logger
      SidekiqUniqueJobs.logger
    end

    # Logs a message at debug level
    # @param message_or_exception [String, Exception] the message or exception to log
    # @yield the message or exception to use for log message
    #   Used for compatibility with logger
    def log_debug(message_or_exception = nil, &block)
      logger.debug(message_or_exception, &block)
      nil
    end

    # Logs a message at info level
    # @param message_or_exception [String, Exception] the message or exception to log
    # @yield the message or exception to use for log message
    #   Used for compatibility with logger
    def log_info(message_or_exception = nil, &block)
      logger.info(message_or_exception, &block)
      nil
    end

    # Logs a message at warn level
    # @param message_or_exception [String, Exception] the message or exception to log
    # @yield the message or exception to use for log message
    #   Used for compatibility with logger
    def log_warn(message_or_exception = nil, &block)
      logger.warn(message_or_exception, &block)
      nil
    end

    # Logs a message at error level
    # @param message_or_exception [String, Exception] the message or exception to log
    # @yield the message or exception to use for log message
    #   Used for compatibility with logger
    def log_error(message_or_exception = nil, &block)
      logger.error(message_or_exception, &block)
      nil
    end

    # Logs a message at fatal level
    # @param message_or_exception [String, Exception] the message or exception to log
    # @yield the message or exception to use for log message
    #   Used for compatibility with logger
    def log_fatal(message_or_exception = nil, &block)
      logger.fatal(message_or_exception, &block)
      nil
    end

    #
    # Wraps the middleware logic with context aware logging
    #
    #
    # @return [nil]
    #
    # @yieldreturn [void] yield to the middleware instance
    def with_logging_context
      with_configured_loggers_context do
        return yield
      end
      nil # Need to make sure we don't return anything here
    end

    #
    # Attempt to setup context aware logging for the given logger
    #
    #
    # @return [void] <description>
    #
    # @yield
    #
    def with_configured_loggers_context(&block)
      if logger.respond_to?(:with_context)
        logger.with_context(logging_context, &block)
      elsif defined?(Sidekiq::Logging)
        Sidekiq::Logging.with_context(logging_context, &block)
      else
        logger.warn "Don't know how to create the logging context. Please open a feature request: https://github.com/mhenrixon/sidekiq-unique-jobs/issues/new?template=feature_request.md"
      end

      nil
    end

    #
    # Setup some variables to add to each log line
    #
    #
    # @return [Hash] the context to use for each log line
    #
    def logging_context
      raise NotImplementedError, "#{__method__} needs to be implemented in #{self.class}"
    end
  end
end
