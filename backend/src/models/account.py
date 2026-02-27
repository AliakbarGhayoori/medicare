from pydantic import BaseModel, Field


class DeleteAccountRequest(BaseModel):
    confirmation: str = Field(..., min_length=1)


class DeleteAccountResponse(BaseModel):
    deleted: bool = True
    message: str = "Your account and all associated data have been permanently deleted."
