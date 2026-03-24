# SPA (Situation Personnel du Jour) Implementation Plan

## Overview
This document outlines the phased implementation of SPA (daily personnel status) scanning, OCR parsing, and application to members.

---

# Phase 1 — Model & Persistence

## 1. Update Member Model
File: `Member.swift`

Add fields:
- position
- observation
- debut
- fin
- computed present/absent status

Requirements:
- Maintain backward-compatible decoding
- Ensure optional fields default safely

---

## 2. Verify Persistence Compatibility
File: `CompanyDirectoryPersistenceService.swift`

- Confirm older JSON still loads correctly
- Validate no crashes on missing new fields

---

## 3. Backup Compatibility
File: `CompanyBackupService.swift`

- Ensure SPA fields are included in:
  - export
  - import
  - backup restore

---

## 4. Preserve SPA Fields in Editing
Files:
- `AddEditMemberViewModel.swift`
- `CompanyDirectoryStore.swift`

- Ensure edits do not overwrite SPA fields unintentionally

---

# Phase 2 — SPA Data Processing Layer

## 5. OCR Extraction Improvements
File: `OCRTextRecognitionService.swift`

Target structured columns:
- Grade
- Nom
- Prénom
- Position
- Observation
- Début
- Fin

---

## 6. Row/Column Reconstruction
- Convert OCR output into tabular structure

---

## 7. SPA Parsing & Normalization
File: `RosterImportService.swift`

Handle:
- empty cells
- handwritten "x"
- row misalignment
- placeholder values like "—"

---

# Phase 3 — Store Logic

## 8. Add SPA Store Methods
File: `CompanyDirectoryStore.swift`

Implement:
- format SPA OCR review text
- parse SPA candidates
- apply selected SPA rows
- return apply summary

---

## 9. Matching Logic
- Match by Nom (primary)
- Rank (secondary)
- Limit to current section

---

## 10. Apply Rules
Only update:
- position
- observation
- debut
- fin

---

# Phase 4 — ViewModel Layer

## 11. ViewModel Methods
File: `SectionDetailViewModel.swift`

- recognize SPA text
- format OCR review
- load candidates
- apply selected rows

---

# Phase 5 — UI Integration

## 12. SPA Entry Point
File: `SectionDetailView.swift`

- Add "Scan Situation" button

---

## 13. SPA Sheet
Include:
- image preview
- OCR review
- detected rows
- selection
- apply button

---

# Phase 6 — Scanning

## 14. Document Scanner
- Add VNDocumentCameraViewController

## 15. Camera Permission
- NSCameraUsageDescription

## 16. Photos Fallback
- Allow image import

---

# Phase 7 — UI Feedback

## 17. Present / Absent Badge
Rules:
- Present → no Début/Fin
- Absent → otherwise

---

## 18. Member Detail
Show:
- status
- position
- observation
- debut
- fin

---

# Phase 8 — Testing

## 19. Regression Checklist
- Old data loads
- Build passes
- Scanner works
- OCR works
- Apply logic correct
- UI reflects state
- Backup works

---

# Execution Order
1. Model + Persistence
2. UI Entry
3. Scanner
4. OCR
5. Parser
6. Selection
7. Apply
8. UI display
9. Backup
10. Testing
