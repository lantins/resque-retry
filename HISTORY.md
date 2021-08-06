# 1.7.5 (2021-08-06)

* Support `retry_delay` methods with different arity
* Switch over to _GitHub_ CI for PR test-execution

# 1.7.4 (2020-10-09)

* Rework how the default `retry_limit` is calculated
* Numerous documentation updates

# 1.7.3 (2019-11-21)

* Do not crash if job class is not found on the resque-web server

# 1.7.2 (2019-11-21)

* Address part 2 of issue #158

# 1.7.1 (2019-07-10)

* Prevent `NoMethodError` when calculating `retry_delay`

# 1.7.0 (2019-06-15)

!!! [Potential] breaking changes -- details below !!!

* Remove support for `args_for_retry` -- it has been deprecated for almost 5
  years
* Work w/ shallow-clone(s) of `args` in `MultipleWithRetrySuppression#save` and
  `Retry.retry_args`
* Remove deprecated options from `Gem::Specification`
* Clean-up formatting in HISTORY.md

# 1.6.0 (2019-04-21)

* Clean-up / refactoring in preparation for a release (`ruby` deprecations,
  etc.)
* Loosen version requirement to allow resque v2.0 and up (@peret)

# 1.5.3 (2018-11-26)

* Monkey patch in the `requeue_queue` method onto the `Resque::Failure` backend
  (this _should_ be a temporary fix)

# 1.5.2 (2018-07-16)

* Remove build support for `ruby < 2.3`, `jruby < 9.1` and `rbx`
* Improving custom retry criteria documentation (@iloveitaly) 

# 1.5.1 (2018-01-07)

* Added build support for `ruby-2.2.x`, `ruby-2.3.x`, `ruby-2.4.x` and
  `ruby-2.5.x`
* Dropped build support for `ruby-1.9.3` and `ruby-2.0.0` (these versions are
  no unsupported)
* Fix some deprecation warnings in tests
* Feature: If no exact exception class is present in `@retry_exceptions` hash,
  try to find closest superclass (@fanfilmu)
* Feature: When running Resque inline, explicitly don't try to retry, don't
  touch Redis (@michaelglass)

# 1.5.0 (2015-10-24)

* Ability to define 'try again' and 'give up' callbacks/hooks (@thenovices)
* Allow `retry_criteria_check` to be registered with Symbols (@thenovices)

## 1.4.0 (2015-01-07)

* Dependency on `resque-scheduler` bumped to ~> 4.0

## 1.3.2 (2014-10-09)

* Fixed: Ensure `#constantize` is called on `Job` instance.

## 1.3.1 (2014-08-13)

* Fixed: Job would infinitely retry if DirtyExit exception was always raised.

## 1.3.0 (2014-07-25)

* Adjust gem dependency on `resque-scheduler` to ~> 3.0
* Deprecated: `args_for_retry` in favor of `retry_args` (will output deprecation
  warnings if your using the older method).
* Feature: Allow changing the args for a given exception using
  `retry_args_for_exception` (@jonp)
* Feature: Allow setting `@expire_retry_key_after` on the fly (@orenmazor)

## 1.2.1 (2014-06-09)

* Fixed Kernel.rand: "invalid argument - 0.0 (ArgumentError)" error with
  "ExponentialBackoff" (on "Rubinius") when `retry_delay_multiplicand_min` and
  `retry_delay_multiplicand_max` were the same value (@saizai)

## 1.2.0 (2014-05-19)

* Fixed scenario where job does not get retried correctly when `perform` is not
  called as expected.
* Feature: Optional `@expire_retry_key_after` settings; expires retry counters
  from redis to save you cleaning up stale state.
* Feature: Expose inner-workings of plugin through debug messages using
  `Resque.logger` (when logging level is Logger:DEBUG).

## 1.1.4 (2014-03-17)

* Fixed displaying retry information in resque web interface, caused by
  `Resque::Helpers` being deprecated.
* Feature: Allow `@fatal_exceptions` as inverse of `@retry_exceptions`, when
  a fatal exception is raised the job will be immediately fail.
* Feature: Allow a random retry delay (within a range) when using exponential
  backoff strategy.

## 1.1.1 (2014-03-12)

* Adjust gem dependency `resque-scheduler`.

## 1.1.0 (2014-03-12)

* Remove dependence on `Resque::Helpers`, will be removed in Resque 2.0
* Use SHA1 for default `#retry_identifier` to prevents issues with long args
  gobbling space.
* Minimum version of Resque is now ~> 1.25

## 1.0.0 (2012-09-07)

** !!! WARNING !!! INCLUDES NON-BACKWARDS COMPATIBLE CHANGES **

* Fixed issues related to infinite job retries and v1.20.0 of resque.
* Minimum gem dependency versions changed: resque >= 1.10.0, resque-scheduler
  >= 1.9.9
* Feature: Setting `@retry_job_delegate` allows you to separate the original job
  from a the retry job. (@tanob/@jniesen)
* Web interface will work without needing to `require` your job code. (n.b.
  less details available via web).
* IMPORTANT: `#identifier` method has been namespaced to `#retry_identifier`.
* Bugfix: `Remove` button on retry web interface was not working.
* Feature: Allow `tagging` exceptions with a module instead of an exception
  class. (@tils - Tilmann Singer)

## 0.2.2 (2011-12-08)

* Feature: Ability to set `retry_delay` per exception type. (Dave Benvenuti)

## 0.2.1 (2011-11-23)

* Bugfix: Fixed error when we tried to parse a number/string as JSON on the
  reque-retry web interface.

## 0.2.0 (2011-11-22)

**INCLUDES NON-BACKWARDS COMPATIBLE CHANGES**

* IMPORTANT: `retry_limit` behaviour has changed. (Nicolas Fouché)
    PREVIOUSLY: 0 == infinite retries.
           NOW: -1 == infinite retries; 0 == means never retry.

* Bugfix: `#redis_retry_key` incorrectly built key when custom identifier was
  used. (Bogdan Gusiev)
* Feature: Ability to sleep worker after re-queuing a job, may be used to bias
  against the same worker from picking up the job again. (Michael Keirnan)
* Feature: Ability to remove retry jobs using resque-web. (Thiago Morello)
* Added example demo application.
* Added Bundler `Gemfile`.

## 0.1.0 (2010-08-29)

* Feature: Multiple failure backend with retry suppression.
* Feature: resque-web tab showing retry information.
* Improved README documentation, added a 'Quick Start' section.

## 0.0.6 (2010-07-12)

* Feature: Added support for custom retry criteria check callbacks.

## 0.0.5 (2010-06-27)

* Handle our own dependancies.

## 0.0.4 (2010-06-16)

* Relax gemspec dependancies.

## 0.0.3 (2010-06-02)

* Bugfix: Make sure that `redis_retry_key` has no whitespace.

## 0.0.2 (2010-05-06)

* Bugfix: Were calling non-existent method to delete redis key.
* Delay no-longer falls back to `sleep`. resque-scheduler is a required
  dependancy.
* Redis key doesn't include ending colon `:` if no args were passed to the job.

## 0.0.1 (2010-04-27)

* First release.
