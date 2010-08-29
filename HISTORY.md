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
* Redis key doesn't include ending colon `:` if no args were passed
  to the job.

## 0.0.1 (2010-04-27)

* First release.