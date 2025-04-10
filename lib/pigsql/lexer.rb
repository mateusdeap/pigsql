require "strscan"

class Lexer
  KEYWORDS = %w(
    SELECT FROM WHERE INSERT INTO VALUES UPDATE SET DELETE
    CREATE TABLE DROP ALTER ADD PRIMARY KEY INTEGER VARCHAR
    AND OR NOT NULL
  ).freeze

  def initialize(input)
    @scanner = StringScanner.new(input)
    @line = 1
    @column = 1
  end

  def next_token
    skip_whitespace

    return nil if @scanner.eos?

    position = { line: @line, column: @column }

    if token = scan_keyword ||
        scan_identifier ||
        scan_number ||
        scan_string ||
        scan_operator ||
        scan_punctuation
      return token + [position]
    end

    # If we get here, we ecountered an unexpected character
    unexpected_char = @scanner.getch
    update_position(unexpected_char)
    [:error, "Unexpected character: #{unexpected_char}", position]
  end

  def tokenize
    tokens = []
    while token = next_token
      tokens << token
      break if token[0] == :error
    end
  end

  private

  def skip_whitespace
    while true
      whitespace = @scanner.scan(/[ \t\r\n]+/)
      if whitespace
        update_position(whitespace)
        next
      end

      if @scanner.scan(/--.*$/)
        update_position(@scanner.matched)
      end
      if @scanner.scan(/\/\*.*?\*\//m)
        update_position(@scanner.matched)
        next
      end
      
      # No more whitespace or comments
      break
    end
  end

    # Match SQL keywords
  def scan_keyword
    # Case-insensitive keyword matching
    KEYWORDS.each do |keyword|
      if @scanner.scan(/#{keyword}\b/i)
        matched = @scanner.matched
        update_position(matched)
        return [:KEYWORD, matched.upcase]
      end
    end
    nil
  end

  # Match identifiers (table names, column names, etc.)
  def scan_identifier
    # Regular identifiers
    if @scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
      matched = @scanner.matched
      update_position(matched)
      return [:IDENTIFIER, matched]
    end
    
    # Quoted identifiers
    if @scanner.scan(/"([^"]*)"/)
      matched = @scanner.matched
      value = @scanner[1]  # Get the content inside quotes
      update_position(matched)
      return [:IDENTIFIER, value]
    end
    
    nil
  end

  # Match numeric literals
  def scan_number
    # Integer
    if @scanner.scan(/\d+/)
      matched = @scanner.matched
      update_position(matched)
      return [:INTEGER, matched.to_i]
    end
    
    # Float with decimal point
    if @scanner.scan(/\d+\.\d+/)
      matched = @scanner.matched
      update_position(matched)
      return [:FLOAT, matched.to_f]
    end
    
    nil
  end

  # Match string literals
  def scan_string
    if @scanner.scan(/'([^']*)'/)
      matched = @scanner.matched
      value = @scanner[1]  # Get the content inside quotes
      update_position(matched)
      return [:STRING, value]
    end
    nil
  end

  # Match operators
  def scan_operator
    operators = {
      '=' => :EQUALS,
      '<' => :LESS_THAN,
      '>' => :GREATER_THAN,
      '<=' => :LESS_EQUAL,
      '>=' => :GREATER_EQUAL,
      '<>' => :NOT_EQUAL,
      '!=' => :NOT_EQUAL,
      '+' => :PLUS,
      '-' => :MINUS,
      '*' => :MULTIPLY,
      '/' => :DIVIDE
    }
    
    # Try to match the longest operators first
    operators.keys.sort_by { |k| -k.length }.each do |op|
      if @scanner.scan(Regexp.new(Regexp.escape(op)))
        matched = @scanner.matched
        update_position(matched)
        return [operators[op], matched]
      end
    end
    
    nil
  end

  # Match punctuation
  def scan_punctuation
    punctuation = {
      '(' => :LPAREN,
      ')' => :RPAREN,
      ',' => :COMMA,
      ';' => :SEMICOLON,
      '.' => :DOT
    }
    
    punctuation.each do |char, type|
      if @scanner.scan(Regexp.new(Regexp.escape(char)))
        matched = @scanner.matched
        update_position(matched)
        return [type, matched]
      end
    end
    
    nil
  end

  # Update line and column position
  def update_position(text)
    lines = text.count("\n")
    if lines > 0
      @line += lines
      @column = text.length - text.rindex("\n") - 1
    else
      @column += text.length
    end
  end
end
