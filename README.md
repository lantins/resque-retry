resque-retry
============

A [Resque][rq] plugin. Requires Resque 1.8.0.

resque-exponential-backoff is a plugin to add retry/exponential backoff to
your resque jobs.

resque-retry provides retry, delay and exponential backoff support for resque jobs.

### Some Features

  - Redis backed retry count/limit.
  - Retry on all or specific exceptions.
  - Exponential backoff (varying the delay between retrys).
  - Small & Extendable - plenty of places to override retry logic/settings.

**n.b.** [resque-scheduler][rqs] is _really_ recommended if you wish to delay between
retry attempts.

Usage
-----

### Retry

    class DeliverWebHook
      extend Resque::Plugins::Retry
      
      def self.perform(url, hook_id, hmac_key)
        heavy_lifting
      end
    end

### Exponential backoff

    class DeliverSMS
      extend Resque::Plugins::ExponentialBackoff
      
      def self.perform(mobile_number, message)
        heavy_lifting
      end
    end

[rq]: http://github.com/defunkt/resque
[rqs]: http://github.com/bvandenbos/resque-scheduler