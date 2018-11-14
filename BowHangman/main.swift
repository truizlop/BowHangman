import Foundation
import Bow

func putString(_ line : String) -> IO<()> {
    return IO.invoke { print(line) }
}

func getString() -> IO<String> {
    return IO.invoke({ Maybe.fromOption(readLine()).getOrElse("") })
}

struct GameState {
    let name : String
    let guesses : Set<Character>
    let word : String
    
    init(name : String, guesses : Set<Character> = Set<Character>(), word : String) {
        self.name = name
        self.guesses = guesses
        self.word = word
    }
    
    var failures : Int {
        return guesses.subtracting(Set<Character>(word)).count
    }
    
    var playerLost : Bool {
        return failures > 8
    }
    
    var playerWon : Bool {
        return Set<Character>(word).subtracting(guesses).isEmpty
    }
    
    func copy(withName name : String? = nil, withGuesses guesses : Set<Character>? = nil, word : String? = nil) -> GameState {
        return GameState(name: name ?? self.name,
                         guesses: guesses ?? self.guesses,
                         word: word ?? self.word)
    }
}

let vocabulary = ["functor", "applicative", "monad", "invariant", "contravariant", "foldable", "traverse", "semigroup", "monoid", "category", "function", "composition"]

func hangman() -> IO<()> {
    return IO<()>.monad().binding(
        { putString("Welcome to purely functional hangman!") },
        { _ in getName() },
        { _, name in putString("Welcome \(name), let's begin!") },
        { _, _, _ in chooseWord() },
        { _, name, _, word in IO.pure(GameState(name: name, word: word)) },
        { _, _, _, _, state in render(state: state) },
        { _, _, _, _, state, _ in gameLoop(state) },
        { _, _, _, _, _, _, _ in IO.pure(())}
        ).fix()
}

func gameLoop(_ state : GameState) -> IO<GameState> {
    return IO<GameState>.monad().binding(
        { getChoice() },
        { guess in IO.pure(state.copy(withGuesses: state.guesses.union(Set<Character>([guess])))) },
        { _, updatedState in render(state: updatedState) },
        { guess, updatedState, _ in gameShouldContinue(updatedState, guess) },
        { _, updatedState, _, continueLoop in continueLoop ? gameLoop(updatedState) : IO.pure(updatedState) }
        ).fix()
}

func gameShouldContinue(_ state : GameState, _ guess : Character) -> IO<Bool> {
    if state.playerWon {
        return putString("Congratulations \(state.name), you won the game!").map{ _ in false }
    } else if state.playerLost {
        return putString("Sorry \(state.name), you lost the game. The word was \(state.word)").map{ _ in false }
    } else if state.word.contains(guess) {
        return putString("You guessed correctly!").map{ _ in true }
    } else {
        return putString("That's wrong, but keep trying!").map{ _ in true }
    }
}

func getName() -> IO<String> {
    return IO<String>.monad().binding(
        { putString("What is your name?") },
        { _ in getString() }
        ).fix()
}

func getChoice() -> IO<Character> {
    return IO<Character>.monad().binding(
        { putString("Please enter a letter") },
        { _ in getString() },
        { _, input in Maybe.fromOption(input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .first).fold(
                { putString("You did not enter a character.").flatMap{ _ in getChoice() } },
                { character in IO.pure(character) }) }
        ).fix()
}

func nextInt(upTo n : UInt32) -> IO<Int> {
    return IO.invoke{ Int(arc4random_uniform(n)) }
}

func chooseWord() -> IO<String> {
    return IO<String>.monad().binding(
        { nextInt(upTo: UInt32(vocabulary.count)) },
        { random in IO.pure(vocabulary[random]) }
        ).fix()
}

func render(state : GameState) -> IO<()> {
    let word = state.word.map { character in state.guesses.contains(character) ? " \(character) " : "   " }.joined()
    let line = state.word.map { _ in " - " }.joined()
    let guesses = "Guesses: \(Array(state.guesses).sorted())"
    let text = "\(word)\n\(line)\n\(guesses)\n"
    return putString(text)
}

try hangman().unsafePerformIO()
