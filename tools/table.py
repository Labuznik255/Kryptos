import sys

def get_possible_dimensions(text_length):
    """Get all possible row/column combinations for the text length."""
    dimensions = []
    for rows in range(1, text_length + 1):
        if text_length % rows == 0:
            cols = text_length // rows
            dimensions.append((rows, cols))
    return dimensions

def create_table(text, rows, cols):
    """Create a table with the given dimensions filled with the text."""
    # Pad text if needed
    text = text.ljust(rows * cols)
    
    # Create the table
    table = []
    for i in range(rows):
        row = []
        for j in range(cols):
            index = i * cols + j
            row.append(text[index])
        table.append(row)
    return table

def print_table(table):
    """Print the table with borders."""
    rows, cols = len(table), len(table[0])
    
    # Create top border
    border = '+'
    for _ in range(cols):
        border += '---+'
    print(border)
    
    # Print rows with borders
    for row in table:
        print('|', end=' ')
        print(' | '.join(row), end=' |\n')
        print(border)
    print()

def create_all_tables(text):
    """Create and print all possible tables for the given text."""
    # Remove spaces from text for consistent tables
    text = text.replace(' ', '')
    text_length = len(text)
    
    print(f"Text: {text}")
    print(f"Length: {text_length}")
    print("Possible arrangements:\n")
    
    dimensions = get_possible_dimensions(text_length)
    
    for rows, cols in dimensions:
        print(f"{rows}x{cols} Table:")
        table = create_table(text, rows, cols)
        print_table(table)

# Example usage
if __name__ == "__main__":
   
    if(len(sys.argv) <= 1):
        print("no text to print")
        exit
    

    for text in sys.argv[1:]:
        create_all_tables(text)
        print("=" * 40 + "\n")
