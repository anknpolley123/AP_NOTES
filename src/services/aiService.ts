import { GoogleGenAI } from "@google/genai";

let genAIInstance: GoogleGenAI | null = null;

const getGenAI = () => {
  if (!genAIInstance) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is not set. Please configure it in your environment.");
    }
    genAIInstance = new GoogleGenAI(apiKey);
  }
  return genAIInstance;
};

export interface SummaryOptions {
  length: 'short' | 'medium' | 'detailed';
  format: 'bullet points' | 'paragraph';
}

const getModel = (modelName: string = "gemini-1.5-flash") => {
  return getGenAI().getGenerativeModel({ model: modelName });
};

export const summarizeText = async (text: string, options: SummaryOptions = { length: 'medium', format: 'bullet points' }): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Summarize the following note text.
Length: ${options.length}
Format: ${options.format}
Maintain a professional yet helpful tone.

Note content:
${text}`;

    const result = await model.generateContent(prompt);
    return result.response.text();
  } catch (error) {
    console.error("Summarization error:", error);
    throw new Error("AI service is currently unavailable.");
  }
};

export const refineText = async (text: string): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Refine the following note text to improve grammar, clarity, and flow. Preserve the original meaning and style, but make it more polished.

Note content:
${text}`;

    const result = await model.generateContent(prompt);
    return result.response.text();
  } catch (error) {
    console.error("Refinement error:", error);
    throw new Error("AI service is currently unavailable.");
  }
};

export const extractActions = async (text: string): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Extract any actionable items, tasks, or follow-ups from the following note text. Format them as a Markdown checklist (- [ ] task). If no tasks are found, say "No clear tasks identified."

Note content:
${text}`;

    const result = await model.generateContent(prompt);
    return result.response.text();
  } catch (error) {
    console.error("Action extraction error:", error);
    throw new Error("AI service is currently unavailable.");
  }
};

export const generateDocument = async (promptText: string, type: string): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Generate a full ${type} based on the following prompt. 
The output should be in Markdown format, well-structured with headers, subheaders, and detailed content. 
Be comprehensive and professional.

Prompt:
${promptText}`;

    const result = await model.generateContent(prompt);
    return result.response.text();
  } catch (error) {
    console.error("Document generation error:", error);
    throw new Error("AI service is currently unavailable.");
  }
};

export const generateImage = async (prompt: string): Promise<string> => {
  try {
    // For image generation, we use the specific Imagen model if available via generateContent 
    // but usually in this environment it's a specific endpoint. 
    // Given the previous code used 'gemini-2.5-flash-image', I'll preserve the structure but fix the call.
    const model = getGenAI().getGenerativeModel({ model: 'gemini-1.5-flash' }); // Fallback pattern
    const result = await model.generateContent(prompt);
    const response = await result.response;
    
    // Check for inlineData in parts
    for (const part of response.candidates?.[0]?.content?.parts || []) {
      if (part.inlineData) {
        return `data:image/png;base64,${part.inlineData.data}`;
      }
    }
    throw new Error("No image data found. Ensure image generation is enabled.");
  } catch (error) {
    console.error("Image generation error:", error);
    throw error;
  }
};

export const translateText = async (text: string, targetLanguage: string): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Translate the following text to ${targetLanguage}. Maintain the original tone and markdown formatting if present.

Text:
${text}`;

    const result = await model.generateContent(prompt);
    return result.response.text();
  } catch (error) {
    console.error("Translation error:", error);
    throw new Error("AI service is currently unavailable.");
  }
};

export const autoFormatText = async (text: string): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Transform the following messy notes or text into a professional document with clear headers, bullet points, and structure. Use bolding for emphasis. Keep it clean and formatted with Markdown.

Text:
${text}`;

    const result = await model.generateContent(prompt);
    return result.response.text();
  } catch (error) {
    console.error("Auto-format error:", error);
    throw new Error("AI service is currently unavailable.");
  }
};

export const spellCheckText = async (text: string): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Fix any spelling and grammatical errors in the following text. Preserve the original tone and strictly return the corrected text only.

Text:
${text}`;

    const result = await model.generateContent(prompt);
    return result.response.text() || text;
  } catch (error) {
    console.error("Spell check error:", error);
    return text;
  }
};

export const chatWithNote = async (
  noteContext: string, 
  userMessage: string, 
  chatHistory: { role: 'user' | 'model', text: string }[] = []
): Promise<string> => {
  try {
    const model = getModel();
    const chat = model.startChat({
      history: [
        { role: 'user', parts: [{ text: `You are a helpful AI study assistant. Here is the context of the current note:\n---\n${noteContext}\n---\nPlease answer questions based on this note.` }] },
        { role: 'model', parts: [{ text: "Understood. I'm ready to help you with this note. What would you like to know?" }] },
        ...chatHistory.map(h => ({ role: h.role, parts: [{ text: h.text }] }))
      ],
    });

    const result = await chat.sendMessage(userMessage);
    return result.response.text();
  } catch (error) {
    console.error("AI Chat error:", error);
    throw new Error("Chat service is currently unavailable.");
  }
};

export const autoTagNote = async (text: string): Promise<string[]> => {
  try {
    const model = getModel();
    const prompt = `Analyze the following note and suggest 3-5 relevant short tags (single words or short phrases). Return them as a comma-separated list only.

Note content:
${text}`;

    const result = await model.generateContent(prompt);
    const tagsStr = result.response.text();
    return tagsStr.split(',').map(t => t.trim().toLowerCase()).filter(t => t.length > 0);
  } catch (error) {
    console.error("Auto-tagging error:", error);
    return [];
  }
};

export const smartSearch = async (
  queryText: string,
  notes: { id: string, title: string, text: string }[]
): Promise<string[]> => {
  try {
    const model = getGenAI().getGenerativeModel({
      model: "gemini-1.5-flash",
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "array" as any,
          items: { type: "string" as any }
        }
      }
    });

    const notesSummary = notes.map(n => `ID: ${n.id}\nTitle: ${n.title}\nContent: ${n.text.substring(0, 100)}...`).join('\n\n');
    const prompt = `You are an AI search engine for notes. Given the user query and the list of notes below, return a list of JSON IDs of the notes that are most relevant to the query. If no notes match, return an empty array [].

Query: ${queryText}

Notes:
${notesSummary}`;

    const result = await model.generateContent(prompt);
    return JSON.parse(result.response.text() || "[]");
  } catch (error) {
    console.error("Smart Search error:", error);
    return [];
  }
};

export const generateQuiz = async (text: string): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Based on the following note, generate 5 multiple-choice questions to test understanding. Provide the questions, options, and indicate the correct answer. Format it nicely in Markdown.

Note:
${text}`;

    const result = await model.generateContent(prompt);
    return result.response.text();
  } catch (error) {
    console.error("Quiz generation error:", error);
    throw new Error("AI service is currently unavailable.");
  }
};

export const generateStudyPlan = async (text: string): Promise<string> => {
  try {
    const model = getModel();
    const prompt = `Create a structured 7-day study plan based on the content of this note. Include daily goals and specific topics to focus on. Use Markdown for formatting.

Note:
${text}`;

    const result = await model.generateContent(prompt);
    return result.response.text();
  } catch (error) {
    console.error("Study plan error:", error);
    throw new Error("AI service is currently unavailable.");
  }
};

export const transcribeAudio = async (base64Audio: string, mimeType: string): Promise<string> => {
  try {
    const model = getModel();
    const result = await model.generateContent([
      { inlineData: { data: base64Audio, mimeType } },
      { text: "Transcribe this audio recording accurately. Strictly return the transcription only." }
    ]);
    return result.response.text();
  } catch (error) {
    console.error("Transcription error:", error);
    throw new Error("AI transcription is currently unavailable.");
  }
};

export const recommendFolders = async (
  notes: { id: string, title: string, text: string }[]
): Promise<{ noteId: string, suggestedFolderName: string }[]> => {
  try {
    const model = getGenAI().getGenerativeModel({
      model: "gemini-1.5-flash",
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "array" as any,
          items: {
            type: "object" as any,
            properties: {
              noteId: { type: "string" as any },
              suggestedFolderName: { type: "string" as any }
            },
            required: ["noteId", "suggestedFolderName"]
          }
        }
      }
    });

    const notesSummary = notes.map(n => `ID: ${n.id}\nTitle: ${n.title}\nContent: ${n.text.substring(0, 50)}...`).join('\n\n');
    const prompt = `You are an AI data analyst. I have a list of notes. Analyze them and suggest a logical folder name for each note. Categorize them into 4-6 broad folder names (e.g., Work, Personal, Study, Ideas). Return the result as a JSON array of objects with noteId and suggestedFolderName.

Notes:
${notesSummary}`;

    const result = await model.generateContent(prompt);
    return JSON.parse(result.response.text() || "[]");
  } catch (error) {
    console.error("Folder recommendation error:", error);
    return [];
  }
};
