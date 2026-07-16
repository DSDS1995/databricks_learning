# Sample Python file for data analysis

import pandas as pd
import numpy as np

def load_data(filepath):
    """Load CSV data from file"""
    return pd.read_csv(filepath)

def analyze_data(df):
    """Perform basic analysis on dataframe"""
    print("Data Shape:", df.shape)
    print("\nData Types:")
    print(df.dtypes)
    print("\nBasic Statistics:")
    print(df.describe())
    return df.describe()

def main():
    """Main execution function"""
    # Example usage
    print("Sample Data Analysis")
    print("=" * 50)
    
    # Create sample data
    sample_data = {
        'id': [1, 2, 3, 4, 5],
        'value': [100, 200, 150, 300, 250],
        'category': ['A', 'B', 'A', 'C', 'B']
    }
    
    df = pd.DataFrame(sample_data)
    print("\nSample DataFrame:")
    print(df)
    
    # Analyze
    analyze_data(df)
    print("\n✓ Analysis complete!")

if __name__ == "__main__":
    main()
