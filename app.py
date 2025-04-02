from fastapi import FastAPI
from pydantic import BaseModel
import fitz  # PyMuPDF
from langchain_deepseek import ChatDeepSeek
from langchain_core.prompts import ChatPromptTemplate
from langchain.text_splitter import CharacterTextSplitter
from langchain_community.vectorstores import FAISS
from fastapi.middleware.cors import CORSMiddleware
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_core.language_models.chat_models import ChatOpenAI

app = FastAPI()

API_KEY = "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"
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
class Consulta(BaseModel):
    query: str

# 🔹 Extraer texto del PDF
def extract_text_from_pdf(pdf_path):
    """ Extrae el texto de un archivo PDF """
    with fitz.open(pdf_path) as doc:
        text = "\n".join([page.get_text("text") for page in doc])
    return text

# 🔹 Procesar PDF e indexarlo con FAISS
def create_vector_store(pdf_path):
    """ Crea una base de datos vectorial a partir del texto del PDF """
    text = extract_text_from_pdf(pdf_path)
    text_splitter = CharacterTextSplitter(chunk_size=5000, chunk_overlap=100)
    text_chunks = text_splitter.split_text(text)
    
    # Usamos HuggingFaceEmbeddings en lugar de DeepSeekEmbeddings
    embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")  # O cualquier modelo de Hugging Face que prefieras
    
    return FAISS.from_texts(text_chunks, embeddings)

# 🔹 Buscar contexto en el PDF
def search_pdf_context(query, k=3):
    docs = vector_store.similarity_search(query, k=k)
    return "\n".join([doc.page_content for doc in docs])
  
def create_langchain_model():
    """ Configura LangChain con OpenRouter """
    return ChatOpenAI(
        openai_api_base=OPENROUTER_URL,
        openai_api_key=API_KEY,
        model_name="deepseek/deepseek-r1-zero:free"
    )
    
# 🔹 Función para invocar el modelo y obtener la respuesta
def langchain_chat(query, context):
    """ Usa LangChain para invocar OpenRouter con el contexto del PDF """
    llm = create_langchain_model()

    # Prompt para LangChain
    prompt = ChatPromptTemplate.from_messages([
        ("system", "Eres un asistente útil que responde preguntas basadas en documentos PDF."),
        ("human", f"Contexto:\n{context}\n\nPregunta: {query}\nRespuesta:")
    ])

    # Encadenar prompt con modelo
    chain = prompt | llm

    # Obtener respuesta del modelo
    response = chain.invoke({"input": query})
    
    return response.content.strip()

# 🔹 Endpoint para procesar la consulta
@app.post("/buscar/")
async def buscar_pregunta(consulta: Consulta):
    try:
        # 🔹 Buscar en el PDF primero
        contexto_pdf = search_pdf_context(consulta.query)
        
        # 🔹 Enviar consulta a DeepSeek con contexto del PDF
        respuesta = langchain_chat(consulta.query, contexto_pdf)

        return {"respuesta": respuesta}

    except Exception as e:
        return {"error": f"Error del servidor: {str(e)}"}

# 🔹 Endpoint de prueba
@app.get("/")
def read_root():
    return {"message": "Bienvenido a DeepSeek!"}

# 🔹 Middleware para evitar problemas de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ⚠️ En producción, cambiar "*" por el dominio correcto
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🔹 Inicialización de la base de datos vectorial
pdf_path = "data/Ley.pdf"  # Asegúrate de poner la ruta correcta de tu PDF
vector_store = create_vector_store(pdf_path)  # Crear la base de datos FAISS