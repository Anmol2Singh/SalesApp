import os

try:
    import pypdf
    print("pypdf is installed")
except ImportError:
    print("pypdf not installed. Installing...")
    os.system("pip install pypdf")
    import pypdf

reader = pypdf.PdfReader("template.pdf")
print("Total Pages:", len(reader.pages))

for idx, page in enumerate(reader.pages):
    print(f"\n--- PAGE {idx+1} ---")
    print(page.extract_text()[:4000]) # Print first 4000 characters of each page
