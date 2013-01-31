env = process.env.NODE_ENV

runtimes =
  runtimes:
    rails: 'ruby_template'
    nodejs: 'nodejs_template'
    django: 'python_template'
    go: 'golang_template'

module.exports = runtimes
