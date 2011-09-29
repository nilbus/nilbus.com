exec = require('child_process').exec

task 'build', 'Rebuild from source', ->
  exec 'coffee -c -o js coffeescripts', (err, stdout, stderr) ->
    console.log "#{stderr}\n#{stdout}"
