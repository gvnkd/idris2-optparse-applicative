||| Test runner for optparse-applicative using Test.Golden.
module Main

import Test.Golden

||| Main entry point for the test runner.
main : IO ()
main = runner
  [ !((testsInDir "." "optparse-applicative") )
  ]
