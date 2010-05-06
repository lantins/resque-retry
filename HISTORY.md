## 0.0.2 (2010-05-06)

* Bugfix: Were calling non-existent method to delete redis key.
* Delay no-longer falls back to `sleep`. resque-scheduler is a required
  dependancy.
* Redis key doesn't include ending colon `:` if no args were passed
  to the job.

## 0.0.1 (2010-04-27)

* First release.