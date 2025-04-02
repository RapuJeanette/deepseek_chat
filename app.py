import re
from fastapi import FastAPI, HTTPException
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import FAISS
from langchain_community.document_loaders import TextLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.schema import Document
from langchain_core.prompts import ChatPromptTemplate

app = FastAPI()

def limpiar_texto(texto):
    texto = re.sub(r'[^\x20-\x7E]', ' ', texto)  # Solo caracteres imprimibles ASCII
    texto = re.sub(r'\s+', ' ', texto).strip()   # Elimina espacios múltiples
    return texto

class CustomTextLoader(TextLoader):
    def lazy_load(self):
        try:
            with open(self.file_path, 'r', encoding='utf-8') as f:
                text = f.read()
        except UnicodeDecodeError:
            try:
                with open(self.file_path, 'r', encoding='latin1') as f:
                    text = f.read()
            except Exception as e:
                raise RuntimeError(f"Error al leer el archivo {self.file_path}: {e}")
        
        # Aplica limpieza de texto
        text = limpiar_texto(text)
        
        return [Document(page_content=text, metadata={})]

# Cargar y dividir el texto
loader = CustomTextLoader(file_path="data/completo.txt")
documents = loader.load()

text_splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
texts = text_splitter.split_documents(documents)

# 🔑 API Key de OpenAI establecida directamente en el código
OPENAI_API_KEY = ""

# Crear embeddings con OpenAI
embeddings = OpenAIEmbeddings(api_key=OPENAI_API_KEY)
db = FAISS.from_documents(texts, embeddings)

# Crear modelo de lenguaje con OpenAI
llm = ChatOpenAI(model_name="gpt-4", api_key=OPENAI_API_KEY)

# Definir plantilla de prompt
prompt = ChatPromptTemplate.from_template("Cuéntame un chiste corto sobre {topic}")
chain = prompt | llm

# Prueba inicial
print(chain.invoke({"topic": "banana"}))

@app.post("/buscar/")
async def buscar(query: dict):
    try:
        pregunta = query["query"]
        docs_similares = db.similarity_search(pregunta, k=3)
        contexto = "\n".join([doc.page_content for doc in docs_similares])
        
        respuesta = llm.predict(f"Usando el siguiente contexto, responde la pregunta:\n{contexto}\nPregunta: {pregunta}")
        
        return {"respuesta": respuesta}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
