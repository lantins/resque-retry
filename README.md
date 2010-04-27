resque-retry
============

A [Resque][rq] plugin. Requires Resque 1.8.0.

resque-retry provides retry, delay and exponential backoff support for
resque jobs.

### Features

  - Redis backed retry count/limit.
  - Retry on all or specific exceptions.
  - Exponential backoff (varying the delay between retrys).
  - Small & Extendable - plenty of places to override retry logic/settings.

**n.b.** [resque-scheduler][rqs] is _really_ recommended if you wish to
delay between retry attempts, otherwise your workers will block
using `sleep`.

Usage / Examples
----------------

Just extend your module/class with this module, and your ready to retry!

Customisation is pretty easy, the below examples should give you
some ideas =), adapt for your own usage and feel free to pick and mix!

### Retry

Retry the job **once** on failure, with zero delay.

    require 'require-retry'

    class DeliverWebHook
      extend Resque::Plugins::Retry

      def self.perform(url, hook_id, hmac_key)
        heavy_lifting
      end
    end

When a job runs, the number of retry attempts is checked and incremented
in Redis. If your job fails, the number of retry attempts is used to
determine if we can requeue the job for another go.

### Custom Retry

    class DeliverWebHook
      extend Resque::Plugins::Retry
      @retry_limit = 10
      @retry_delay = 120

      def self.perform(url, hook_id, hmac_key)
        heavy_lifting
      end
    end

The above modification will allow your job to retry upto 10 times, with
a delay of 120 seconds, or 2 minutes between retry attempts.

Alternatively you could override the `retry_delay` method to do something
more special.

### Exponential Backoff

Use this if you wish to vary the delay between retry attempts:

    class DeliverSMS
      extend Resque::Plugins::ExponentialBackoff

      def self.perform(mobile_number, message)
        heavy_lifting
      end
    end

**Default Settings**

    key: m = minutes, h = hours

                  no delay, 1m, 10m,   1h,    3h,    6h
    @backoff_strategy = [0, 60, 600, 3600, 10800, 21600]

The first delay will be 0 seconds, the 2nd will be 60 seconds, etc...
Again, tweak to your own needs.

The number if retrys is equal to the size of the `backoff_strategy`
array, unless you set `retry_limit` yourself.

### Retry Specific Exceptions

The default will allow a retry for any type of exception. You may change
it so only specific exceptions are retried using `retry_exceptions`:

    class DeliverSMS
      extend Resque::Plugins::Retry
      @retry_exceptions = [NetworkError]
      
      def self.perform(mobile_number, message)
        heavy_lifting
      end
    end

The above modification will **only** retry if a `NetworkError` (or subclass)
exception is thrown.

Customise & Extend
------------------

Please take a look at the yardoc/code for more details on methods you may
wish to override.

Some things worth noting:

### Job Identifier/Key

The retry attempt is incremented and stored in a Redis key. The key is
built using the `identifier`. If you have a lot of arguments or really long
ones, you should consider overriding `identifier` to define a more precise
or loose custom identifier.

The default identifier is just your job arguments joined with a dash `-`.

By default the key uses this format: 
`resque-retry:<job class name>:<identifier>`.

Or you can define the entire key by overriding `redis_retry_key`.

   class DeliverSMS
     extend Resque::Plugins::Retry

     def self.identifier(mo_id, mobile_number, message)
       "#{mobile_number}:#{mo_id}"
     end

     self.perform(mo_id, mobile_number, message)
       heavy_lifting
     end
   end

### Retry Arguments

cats maiow

Install
-------

    $ gem install resque-retry

[rq]: http://github.com/defunkt/resque
[rqs]: http://github.com/bvandenbos/resque-scheduler