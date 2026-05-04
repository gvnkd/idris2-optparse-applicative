||| Test runner for optparse-applicative example using Test.Golden.
module Main

import Test.Golden

main : IO ()
main = runner
  [ !((testsInDir "." "optparse-applicative-example") )
  ]
