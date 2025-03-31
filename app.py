from fastapi import FastAPI
from pydantic import BaseModel
import fitz  # PyMuPDF
import requests
import json
from langchain.text_splitter import CharacterTextSplitter
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.vectorstores import FAISS
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

DEEPSEEK_API_KEY = "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"
DEEPSEEK_URL = "https://openrouter.ai/api/v1/chat/completions"

class Consulta(BaseModel):
    query: str
    
# 🔹 Extraer texto del PDF
def extract_text_from_pdf(pdf_path):
    with fitz.open(pdf_path) as doc:
        text = "\n".join([page.get_text("text") for page in doc])
    return text

# 🔹 Procesar PDF e indexarlo con FAISS
def create_vector_store(pdf_path):
    text = extract_text_from_pdf(pdf_path)
    text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=100)
    text_chunks = text_splitter.split_text(text)
    embeddings = OpenAIEmbeddings(openai_api_key=DEEPSEEK_API_KEY)
    return FAISS.from_texts(text_chunks, embeddings)

# 🔹 Función para consultar DeepSeek
def deepseek_chat(query, context):
    headers = {
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        "Content-Type": "application/json",
    }
    data = {
        "model": "deepseek/deepseek-r1-zero:free",
        "messages": [{"role": "user", "content": f"Contexto: {context}\n\nPregunta: {query}\nRespuesta:"}]
    }
    
    response = requests.post(DEEPSEEK_URL, headers=headers, data=json.dumps(data))
    
    try:
        result = response.json()
        print("🔍 Respuesta completa de DeepSeek:", result)  # <-- Agregar esto para depuración
        return result.get("choices", [{}])[0].get("message", {}).get("content", "No se encontró respuesta.")
    except json.JSONDecodeError:
        return "⚠️ Error al interpretar la respuesta de la API"

# 🔹 Endpoint de la API para recibir consultas
@app.post("/buscar/")
def buscar_pregunta(consulta: Consulta):
    pdf_text = extract_text_from_pdf("data/Ley.pdf")
    respuesta = deepseek_chat(consulta.query, pdf_text)
    return {"respuesta": respuesta}

@app.get("/buscar/")
def buscar(query: str):
    return {"respuesta": f"Recibido: {query}"}

@app.get("/")
def read_root():
    return {"message": "Bienvenido a DeepSeek!"}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ⚠️ En producción, cambia "*" por el dominio correcto
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
