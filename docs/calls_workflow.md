# Function Call Workflow Diagram

This diagram illustrates how the DSL combinators in `Options.Applicative.Builder` map down to the core GADT constructors defined in `Options.Applicative.Types`.

## Overview
Top-level wrapper functions dispatch parsing tasks, while builder functions construct specific primitive parsers. All execution paths eventually resolve into the core `Parser` GADT (`Flag`, `Option`, `Argument`, `Alt`, `Pure`).

```mermaid
graph TD
    subgraph BuilderLayer [Builder DSL Combinators]
        A[info p desc] -->|returns parser directly| P((Parser a))
        
        B[subparser commands] --> C{commands list}
        C -- [] --> D[?rhs_subparser_empty_case<br/>Pending Alternative.empty]
        C -- cons :: ps --> E[GADT: Alt p subparser_ps]
        E -->|first branch| F[p : Parser a]
        E -->|recursive tail| G[subparser ps]

        H[strOption names] --> I[GADT: Option names ARG]
        K[flag' names] --> L[GADT: Flag names]
        M[argument metavar] --> N[GADT: Argument metavar]
        
        O[option names defaultValue] --> P1[GADT: Alt p_req p_fallback]
        P1 -->|required option| Q[GADT: Option names ARG]
        P1 -->|fallback default| R[GADT: Pure defaultValue]
    end

    subgraph CoreTypes [Options.Applicative.Types GADT Constructors]
        I & Q --> S[Option :: List String -> Parser String]
        L --> T[Flag :: List String -> Parser Bool]
        N --> U[Argument :: String -> Parser String]
        E & P1 --> V[Alt :: Parser a -> Parser a -> Parser a]
        R --> W[Pure :: a -> Parser a]
    end
    
    A --> H & K & M & O & B

    classDef core fill:#e1f5fe,stroke:#01579b,stroke-width:2px;
    class S,T,U,V,W,I,L,N,Q,R,E,P1,D core;
```

## Call Flow Explanation
1. **`info p desc`**: Currently acts as an identity wrapper for the parser `p`. The `desc` string is reserved for future help-generation integration (Phase 2).
2. **`subparser commands`**: Recursively processes a list of named subcommands (`(String, Parser a)`). It chains them together using the `Alt` (Alternative) combinator, creating an N-ary choice between subparsers. The empty base case is currently pending implementation via the `Alternative` instance for `Parser`.
3. **`strOption`, `flag'`, `argument`**: Direct mappings to their respective core GADT constructors (`Option`, `Flag`, `Argument`). They handle primitive CLI inputs.
4. **`option names defaultValue`**: Constructs a fallback mechanism by combining an `Option` parser and a `Pure` parser using the `Alt` combinator. If the option is present on the CLI, it parses; otherwise, it falls back to the default value.

## Future Phase 2 Expansions
- **Modifiers:** Functions like `long`, `short`, and `help` will intercept calls between Builder and Core Types to attach metadata before GADT construction.
- **Help Generation:** The `desc` argument in `info` will branch out to the `Help.idr` module for usage text rendering.
