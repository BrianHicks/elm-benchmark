const fs = require('fs')
const path = require('path')
const proc = require('child_process')
const which = require('which')

const elmPackageJson = 'elm-package.json'
const benchDir = path.resolve('benchmarks')

const ensureBenchDir = () => {
  try {
    fs.mkdirSync(benchDir)
    console.log(`Created: ${benchDir}`)
  } catch (e) {
    if (!e.message.startsWith('EEXIST')) {
      throw e
    }
  }
}

const prepareElmPackageJson = () => {
  var rootJson = {}
  try {
    rootJson = JSON.parse(fs.readFileSync(path.resolve(elmPackageJson)))
  } catch(e) {
    if (e.message.startsWith('ENOENT')) {
      console.error(`Missing ${elmPackageJson} file.`)
      process.exit(1)
    } else {
      throw e
    }
  }
  const newSourceDirs =
    rootJson['source-directories']
      .map(dir => path.join('..', dir))
      .concat('.')
  const benchJson = Object.assign(rootJson, {
    'summary': 'Benchmark for the parent project',
    'dependencies': Object.assign(rootJson.dependencies, {
      'BrianHicks/elm-benchmark': '2.0.1 <= v < 3.0.0'
    }),
    'exposed-modules': [],
    'source-directories': newSourceDirs
  })
  const target = path.join(benchDir, elmPackageJson)
  const contents = JSON.stringify(benchJson, null, 4) + '\n'
  ensureFile(target, contents)
}

const ensureFile = (target, contents) => {
  try {
    fs.writeFileSync(target, contents, {flag: 'wx'})
    console.log(`Created: ${target}`)
  } catch(e) {
    if (!e.message.startsWith('EEXIST')) {
      throw e
    }
  }
}

const elmBinPath = (bin) => {
  var elmBin = bin
  const localElmBin = path.resolve(path.join('node_modules', '.bin', elmBin))
  if (fs.existsSync(localElmBin)) {
    elmBin = localElmBin
  } else {
    try {
      which.sync(elmBin)
    } catch(e) {
      if (e.message.startsWith('not found')) {
        console.error(`${bin} not found!`)
        process.exit(1)
      } else {
        throw e
      }
    }
  }
  return elmBin
}

const installElmPackage = () => {
  execElmBinInBenchDir('elm-package', ['install', '--yes'])
}

const execElmBinInBenchDir = (bin, args) => {
  cmd = [elmBinPath(bin), ...args].join(' ')
  if (!fs.existsSync(benchDir)) {
    console.error('Missing benchmarks/ directory. Run `elm-benchmark init` first.')
    process.exit(1)
  }
  proc.execSync(cmd, {
    stdio: 'inherit',
    cwd: benchDir,
  })
}

const stubAppFile = `module Benchmarks exposing (main)

import Benchmark exposing (..)
import Benchmark.Runner exposing (BenchmarkProgram, program)


sampleSuite : Benchmark
sampleSuite =
    let
        longString =
            String.repeat 100 "abcdefgh"

        mapper char =
            case char of
                'd' ->
                    'D'

                _ ->
                    char
    in
        describe "Sample benchmark"
            [ describe "String.map"
                [ benchmark "replace characters in a long string" <|
                    \\_ -> String.map mapper longString
                ]
            ]


main : BenchmarkProgram
main =
    program sampleSuite
`

const benchAppFile = path.join(benchDir, 'Benchmarks.elm')

const init = () => {
  ensureBenchDir()
  prepareElmPackageJson()
  installElmPackage()
  ensureFile(benchAppFile, stubAppFile)
  console.log('Done initializing!')
}

const defaultCompileTarget = 'docs/index.html'

const compileTarget = () => {
  const args = process.argv.slice(1)
  if (args.length >= 3) {
    return args[2]
  } else {
    return defaultCompileTarget
  }
}

const compile = () => {
  execElmBinInBenchDir('elm-make', [benchAppFile, '--yes', '--output', path.resolve(compileTarget())])
}

const help = () => {
  console.log(`elm-benchmark [init|install|compile|help] [compileOutputFile]

  - init    : Prepares benchmarks/ directory and install packages.
  - install : Only installs packages specified in benchmarks/${elmPackageJson}.
  - compile : Compiles benchmarks/Benchmarks.elm into \`compileOutputFile\`.
              \`compileOutputFile\` defaults to ${defaultCompileTarget}
  - help    : Prints this help.
  `)
  process.exit(1)
}

const mode = () => {
  const args = process.argv.slice(1)
  var mode = 'help'
  if (args.length >= 2) {
    if (args[1] == 'install') {
      mode = 'install'
    } else if (args[1] == 'init') {
      mode = 'init'
    } else if (args[1] == 'compile') {
      mode = 'compile'
    }
  }
  return mode
}

const main = () => {
  switch (mode()) {
    case 'help':
      help()
      break
    case 'init':
      init()
      break
    case 'install':
      installElmPackage()
      break
    case 'compile':
      compile()
      break
    default:
      help()
  }
}

main()
