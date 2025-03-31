from fastapi import FastAPI
import fitz  # PyMuPDF
import requests
import json
from langchain_community.embeddings import OpenAIEmbeddings
from langchain.chains import LLMChain
from langchain_community.vectorstores import FAISS
from langchain.text_splitter import CharacterTextSplitter
from langchain.prompts import PromptTemplate

app = FastAPI()

DEEPSEEK_API_KEY = "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"
DEEPSEEK_URL = "https://openrouter.ai/api/v1/chat/completions"

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
    embeddings = OpenAIEmbeddings()  # Aquí puede ser reemplazado por cualquier otro tipo de embeddings compatible
    return FAISS.from_texts(text_chunks, embeddings)

# 🔹 Función para consultar DeepSeek a través de LangChain
def deepseek_chat_with_langchain(query, context):
    # Usar LangChain para interactuar con DeepSeek
    template = "Contexto: {context}\n\nPregunta: {query}\nRespuesta:"
    prompt = PromptTemplate(input_variables=["context", "query"], template=template)
    
    # Crear la cadena de consulta de LangChain
    llm_chain = LLMChain(llm=deepseek_model(), prompt=prompt)
    
    response = llm_chain.run({"context": context, "query": query})
    return response

# 🔹 Función para configurar DeepSeek como modelo
def deepseek_model():
    # Aquí definimos cómo Deepseek se integrará a LangChain.
    return CustomDeepSeekLLM()

class CustomDeepSeekLLM:
    def __call__(self, prompt: str) -> str:
        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json",
        }
        data = {
            "model": "deepseek/deepseek-r1-zero:free",
            "messages": [{"role": "user", "content": prompt}]
        }
        response = requests.post(DEEPSEEK_URL, headers=headers, data=json.dumps(data))
        result = response.json()
        return result.get("choices", [{}])[0].get("message", {}).get("content", "No se encontró respuesta.")

# 🔹 Endpoint de la API para recibir consultas
@app.post("/buscar/")
async def buscar_pregunta(query: str):
    # Extraer el texto del PDF
    pdf_text = extract_text_from_pdf("data/Ley.pdf")
    
    # Consulta Deepseek a través de LangChain
    respuesta = deepseek_chat_with_langchain(query, pdf_text)
    
    return {"respuesta": respuesta}

@app.get("/")
def read_root():
    return {"message": "Bienvenido a DeepSeek!"}