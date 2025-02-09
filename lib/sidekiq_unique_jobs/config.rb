# frozen_string_literal: true

module SidekiqUniqueJobs
  # ThreadSafe config exists to be able to document the config class without errors
  ThreadSafeConfig = Concurrent::MutableStruct.new("ThreadSafeConfig",
                                                   :default_lock_timeout,
                                                   :default_lock_ttl,
                                                   :enabled,
                                                   :unique_prefix,
                                                   :logger,
                                                   :locks,
                                                   :strategies,
                                                   :debug_lua,
                                                   :max_history,
                                                   :reaper,
                                                   :reaper_count,
                                                   :reaper_interval,
                                                   :reaper_timeout,
                                                   :lock_info)

  #
  # Shared class for dealing with gem configuration
  #
  # @author Mauro Berlanda <mauro.berlanda@gmail.com>
  class Config < ThreadSafeConfig
    LOCKS_WHILE_ENQUEUED = {
      until_executing: SidekiqUniqueJobs::Lock::UntilExecuting,
      while_enqueued: SidekiqUniqueJobs::Lock::UntilExecuting,
    }.freeze

    LOCKS_FROM_PUSH_TO_PROCESSED = {
      until_completed: SidekiqUniqueJobs::Lock::UntilExecuted,
      until_executed: SidekiqUniqueJobs::Lock::UntilExecuted,
      until_performed: SidekiqUniqueJobs::Lock::UntilExecuted,
      until_processed: SidekiqUniqueJobs::Lock::UntilExecuted,
      until_and_while_executing: SidekiqUniqueJobs::Lock::UntilAndWhileExecuting,
      until_successfully_completed: SidekiqUniqueJobs::Lock::UntilExecuted,
    }.freeze

    LOCKS_WITHOUT_UNLOCK = {
      until_expired: SidekiqUniqueJobs::Lock::UntilExpired,
    }.freeze

    LOCKS_WHEN_BUSY = {
      around_perform: SidekiqUniqueJobs::Lock::WhileExecuting,
      while_busy: SidekiqUniqueJobs::Lock::WhileExecuting,
      while_executing: SidekiqUniqueJobs::Lock::WhileExecuting,
      while_working: SidekiqUniqueJobs::Lock::WhileExecuting,
      while_executing_reject: SidekiqUniqueJobs::Lock::WhileExecutingReject,
    }.freeze

    LOCKS =
      LOCKS_WHEN_BUSY.dup
                     .merge(LOCKS_WHILE_ENQUEUED.dup)
                     .merge(LOCKS_WITHOUT_UNLOCK.dup)
                     .merge(LOCKS_FROM_PUSH_TO_PROCESSED.dup)
                     .freeze

    STRATEGIES = {
      log: SidekiqUniqueJobs::OnConflict::Log,
      raise: SidekiqUniqueJobs::OnConflict::Raise,
      reject: SidekiqUniqueJobs::OnConflict::Reject,
      replace: SidekiqUniqueJobs::OnConflict::Replace,
      reschedule: SidekiqUniqueJobs::OnConflict::Reschedule,
    }.freeze

    PREFIX          = "uniquejobs"
    LOCK_TIMEOUT    = 0
    LOCK_TTL        = nil
    ENABLED         = true
    DEBUG_LUA       = false
    MAX_HISTORY     = 1_000
    REAPER          = :ruby # The type of cleanup to run. Possible values are [:ruby, :lua]
    REAPER_COUNT    = 1_000
    REAPER_INTERVAL = 600 # Every 10 minutes
    REAPER_TIMEOUT  = 10 # 10 seconds
    USE_LOCK_INFO   = false

    #
    # Returns a default configuration
    #
    # @example
    #   SidekiqUniqueJobs::Config.default => <concurrent/mutable_struct/thread_safe_config SidekiqUniqueJobs::Config {
    #   default_lock_timeout: 0,
    #   default_lock_ttl: nil,
    #   enabled: true,
    #   unique_prefix: "uniquejobs",
    #   logger: #<Sidekiq::Logger:0x00007f81e096b0e0 @level=1 ...>,
    #   locks: {
    #     around_perform: SidekiqUniqueJobs::Lock::WhileExecuting,
    #     while_busy: SidekiqUniqueJobs::Lock::WhileExecuting,
    #     while_executing: SidekiqUniqueJobs::Lock::WhileExecuting,
    #     while_working: SidekiqUniqueJobs::Lock::WhileExecuting,
    #     while_executing_reject: SidekiqUniqueJobs::Lock::WhileExecutingReject,
    #     until_executing: SidekiqUniqueJobs::Lock::UntilExecuting,
    #     while_enqueued: SidekiqUniqueJobs::Lock::UntilExecuting,
    #     until_expired: SidekiqUniqueJobs::Lock::UntilExpired,
    #     until_completed: SidekiqUniqueJobs::Lock::UntilExecuted,
    #     until_executed: SidekiqUniqueJobs::Lock::UntilExecuted,
    #     until_performed: SidekiqUniqueJobs::Lock::UntilExecuted,
    #     until_processed: SidekiqUniqueJobs::Lock::UntilExecuted,
    #     until_and_while_executing: SidekiqUniqueJobs::Lock::UntilAndWhileExecuting,
    #     until_successfully_completed: SidekiqUniqueJobs::Lock::UntilExecuted
    #   },
    #   strategies: {
    #     log: SidekiqUniqueJobs::OnConflict::Log,
    #     raise: SidekiqUniqueJobs::OnConflict::Raise,
    #     reject: SidekiqUniqueJobs::OnConflict::Reject,
    #     replace: SidekiqUniqueJobs::OnConflict::Replace,
    #     reschedule: SidekiqUniqueJobs::OnConflict::Reschedule
    #   },
    #   debug_lua: false,
    #   max_history: 1000,
    #   reaper:: ruby,
    #   reaper_count: 1000,
    #   lock_info: false
    #   }>
    #
    #
    # @return [SidekiqUniqueJobs::Config] a default configuration
    #
    def self.default # rubocop:disable Metrics/MethodLength
      new(
        LOCK_TIMEOUT,
        LOCK_TTL,
        ENABLED,
        PREFIX,
        Sidekiq.logger,
        LOCKS,
        STRATEGIES,
        DEBUG_LUA,
        MAX_HISTORY,
        REAPER,
        REAPER_COUNT,
        REAPER_INTERVAL,
        REAPER_TIMEOUT,
        USE_LOCK_INFO,
      )
    end

    #
    # Adds a lock type to the configuration. It will raise if the lock exists already
    #
    # @example Add a custom lock
    #   add_lock(:my_lock, CustomLocks::MyLock)
    #
    # @raise DuplicateLock when the name already exists
    #
    # @param [String, Symbol] name the name of the lock
    # @param [Class] klass the class describing the lock
    #
    # @return [void]
    #
    def add_lock(name, klass)
      lock_sym = name.to_sym
      raise DuplicateLock, ":#{name} already defined, please use another name" if locks.key?(lock_sym)

      new_locks = locks.dup.merge(lock_sym => klass).freeze
      self.locks = new_locks
    end

    #
    # Adds an on_conflict strategy to the configuration.
    #
    # @example Add a custom strategy
    #   add_lock(:my_strategy, CustomStrategies::MyStrategy)
    #
    # @raise [DuplicateStrategy] when the name already exists
    #
    # @param [String] name the name of the custom strategy
    # @param [Class] klass the class describing the strategy
    #
    def add_strategy(name, klass)
      strategy_sym = name.to_sym
      raise DuplicateStrategy, ":#{name} already defined, please use another name" if strategies.key?(strategy_sym)

      new_strategies = strategies.dup.merge(strategy_sym => klass).freeze
      self.strategies = new_strategies
    end
  end
end
