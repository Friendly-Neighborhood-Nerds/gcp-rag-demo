import os
from fastapi import FastAPI
from langchain_google_vertexai import ChatVertexAI, VertexAIEmbeddings
from langchain_community.vectorstores import FAISS
from langchain.document_loaders import GCSDirectoryLoader
from langchain_core.prompts import ChatPromptTemplate
from langchain.chains.combine_documents import create_stuff_documents_chain
from langchain.text_splitter import RecursiveCharacterTextSplitter

app = FastAPI()

BUCKET_NAME = os.environ.get("BUCKET_NAME")
PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT")

if not BUCKET_NAME:
    raise ValueError("Environment variable BUCKET_NAME is required")
if not PROJECT:
    raise ValueError("Environment variable GOOGLE_CLOUD_PROJECT is required")

llm = ChatVertexAI(
    model="gemini-2.5-pro",
    temperature=0,
    location="europe-west1"
)

vectorstore = None
retriever = None


@app.get("/ask")
async def ask(question: str):
    prompt = ChatPromptTemplate.from_messages([
        ("system", "Gib Auskunft auf folgendes Prompt basierend auf den mitgelieferten Werbedokumenten. {context}"),
        ("human", "{input}"),
    ])
    chain = create_stuff_documents_chain(llm, prompt)
    context_docs = retriever.invoke(question)
    print(context_docs)
    response = chain.invoke({"input": question, "context": context_docs})
    print(response)
    return {"answer": response}

@app.get("/index")
async def index():
    global vectorstore, retriever
    # Only for quick and dirty. This uses unstructured AI lib -> rather list all items and then parse them with a proper PDF reader
    docs = GCSDirectoryLoader(project_name=PROJECT, bucket=BUCKET_NAME).load() 
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=500,      
        chunk_overlap=50     
    )
    chunked_docs = text_splitter.split_documents(docs)
    embeddings = VertexAIEmbeddings(model_name="gemini-embedding-001", location="europe-west1")
    vectorstore = FAISS.from_documents(chunked_docs , embeddings)
    retriever = vectorstore.as_retriever(search_type="mmr", search_kwargs={"k": 1})

