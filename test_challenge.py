def calculate_fibonacci(n):
    """
    Calculate the nth Fibonacci number.
    
    Args:
        n (int): The position in the Fibonacci sequence (0-based)
        
    Returns:
        int: The nth Fibonacci number
    """
    if n < 0:
        raise ValueError("Input must be a non-negative integer")
    if n <= 1:
        return n
        
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b

# Test cases
def test_fibonacci():
    test_cases = [
        (0, 0),
        (1, 1),
        (2, 1),
        (3, 2),
        (4, 3),
        (5, 5),
        (6, 8),
        (7, 13),
        (8, 21),
        (9, 34),
        (10, 55)
    ]
    
    for n, expected in test_cases:
        result = calculate_fibonacci(n)
        print(f"fibonacci({n}) = {result} (expected: {expected})")
        assert result == expected, f"Test failed for n={n}"
    
    print("All tests passed!")

if __name__ == "__main__":
    test_fibonacci() 