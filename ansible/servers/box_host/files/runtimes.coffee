env = process.env.NODE_ENV

runtimes =
  production:
    runtimes:
      rails: 'ruby_container_template'

module.exports = runtimes[env]
