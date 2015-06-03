# tika_wrapper

Wrap any task with a running tika server:

```ruby
TikaWrapper.wrap do |tika|
  # Something that requires tika
end
```

## Basic Options

```ruby
TikaWrapper.wrap port: '9998'
```