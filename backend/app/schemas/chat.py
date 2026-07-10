"""
Chat Schemas

Pydantic models for request/response validation in chat endpoints.
"""
from pydantic import BaseModel, Field
from typing import Optional


class SendMessageRequest(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class ChatMessageResponse(BaseModel):
    id: str
    conversation_id: str
    sender_id: str
    receiver_id: str
    content: str
    created_at: str
    read_at: Optional[str] = None


class ConversationPreviewResponse(BaseModel):
    conversation_id: str
    partner_id: str
    partner_name: str
    partner_avatar_url: Optional[str] = None
    last_message: Optional[str] = None
    last_message_at: Optional[str] = None
    unread_count: int = 0


class MarkReadResponse(BaseModel):
    marked_count: int
