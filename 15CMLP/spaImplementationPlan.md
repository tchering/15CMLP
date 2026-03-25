# Updated SPA Implementation Plan

## 1. Change add/edit labels first.
- Rename **Name** to **NOM**.
- Rename **Rank** to **GRADE**.
- Keep **Phone Number** optional.
- This is a UI terminology update only; underlying code can still keep `name` and `rank` internally.

## 2. Extend the Member model with SPA-specific fields.
- Add dedicated SPA fields instead of reusing existing profile fields:
  - `spaPosition`
  - `spaObservation`
  - `spaStartDate`
  - `spaEndDate`
  - `spaLastUpdatedAt`
- Add computed helpers for:
  - current presence status
  - formatted SPA date display
  - active assignment check for today
- Keep `name`, `rank`, and `phoneNumber` as stable member identity/contact data.

## 3. Make persistence backward-compatible.
- Update `Member` decoding so older saved JSON still loads safely.
- New SPA fields should decode as optional / empty by default.
- Saving should include SPA fields once present.

## 4. Add a dedicated SPA data model.
- Create a separate type for scanned SPA rows, for example `SPAEntry`.
- Fields:
  - `grade`
  - `nom`
  - `position`
  - `observation`
  - `debut`
  - `fin`
  - `matchedMemberID`
  - `matchStatus`
  - `rawSourceText`
- This keeps daily SPA updates separate from roster import and member creation.

## 5. Replace OCR table reconstruction with LLM-based row extraction.
- Do not manually reconstruct table columns from OCR.
- New architecture:
  - Scan image
  - OCR extracts raw text
  - raw text is sent to LLM
  - LLM reconstructs rows and returns structured JSON
  - review UI displays parsed rows
  - validated rows are applied to matched members

### Use this extraction prompt logic
- OCR extraction system for French SPA personnel sheets
- strict output column order: `Grade | Nom | Position | Observation | Début | Fin`
- extract only true personnel rows
- ignore title/header/footer/stats/summary blocks
- each row is one person only
- valid grades include: `LTN, SCH, SGT, CC1, CCH, CPL, 1CL, SDT`
- if field missing, return empty string
- preserve accents and punctuation
- reconstruct rows even if OCR text is split

### Mandatory validation inside the LLM step before returning JSON
- each row must contain exactly one grade
- `Nom` must not be a first name
- `Prénom` should not appear in final output
- `Position` must be a known short code, not a name
- `Début` and `Fin` must be valid dates only
- no row may contain multiple people
- if ambiguous, split or correct using best judgment

### Final LLM response format
- JSON array only
- no markdown
- no explanation
- no ASCII table

## 6. Add an app-side validation layer after LLM output.
- Even if the LLM validates, the app should still verify:
  - grade is supported
  - dates parse correctly in `DD/MM/YYYY`
  - position is either empty or a known short code
  - no duplicate or malformed rows
- Reject invalid JSON rows before review/apply.
- Mark suspicious rows for user review instead of silently applying them.

## 7. Add SPA-to-member matching logic.
- Match scanned rows to existing soldiers in the selected section using normalized:
  - `GRADE + NOM`
- Normalize case, accents, spacing, punctuation, OCR noise.
- Matching results:
  - exact match
  - no match
  - multiple matches
- Only exact matches should be eligible for automatic update.

## 8. Add SPA review UI.
- Create a dedicated scan/review flow separate from roster import.
- Review screen should show extracted SPA rows in a clean table:
  - `GRADE`
  - `NOM`
  - `Position`
  - `Observation`
  - `Début`
  - `Fin`
  - `Matched soldier`
- User should be able to:
  - review extracted rows
  - deselect rows
  - see unmatched/ambiguous entries
  - confirm before applying updates

## 9. Apply SPA updates as partial member updates only.
- Add a store method such as `applySPAEntries(_:to:)`.
- For matched members, update only:
  - `spaPosition`
  - `spaObservation`
  - `spaStartDate`
  - `spaEndDate`
  - `spaLastUpdatedAt`
- Never overwrite:
  - `name`
  - `rank`
  - `phoneNumber`
  - `role`
  - `memoryTip`
- Do not create new soldiers from SPA scan.

## 10. Define present/absent status centrally.
- Use one consistent rule in the model layer.
- Current intended rule:
  - if SPA dates are empty, soldier is **Present**
  - if dates exist and today falls in the inclusive range, soldier is **Absent**
  - if dates exist but today is outside the range, soldier is **Present**
- This should be shared by profile screen, section list, and future summaries.

## 11. Update member profile UI.
- In the member detail screen, add:
  - Present / Absent badge
  - Position
  - Observation
  - Début
  - Fin
- Keep existing grade/name/profile info intact.

## 12. Update section list UI for daily operational use.
- Show current status badge on each soldier row.
- Optionally surface current SPA position or mission label when absent.
- This makes the section screen usable as a live daily availability board.

## 13. Separate “Scan SPA” from existing roster import.
- Current OCR import is for roster/member creation.
- SPA is operational status update and should be a different entry point.
- Toolbar/menu should become something like:
  - Add Member
  - Import Roster
  - Scan SPA

## 14. Add date parsing and formatting utilities.
- Parse French format `DD/MM/YYYY`.
- Handle empty values safely.
- Treat `Fin` as inclusive.
- Normalize OCR/LLM edge cases if needed.

## 15. Add tests before rollout.
- Member persistence migration tests
- SPA date/status logic tests
- JSON decoding/validation tests for LLM output
- member matching tests with OCR normalization
- apply-update tests to ensure identity fields never change

## Final Architecture
`Scan image -> OCR -> raw text -> LLM extraction/validation -> JSON rows -> Review UI -> Apply matched updates to members`

## Important implementation note
The current `RosterImportService` should remain for roster creation/import. SPA should be built as a parallel pipeline, not forced into the existing roster parser, because the responsibilities are different.

## One correction to your prompt
Your latest prompt mentions `Prénom` in validation, but your final strict output format does not include `Prénom`. That is fine, but in implementation the LLM should use `Prénom` only internally for row reconstruction/validation and return only:

- `Grade`
- `Nom`
- `Position`
- `Observation`
- `Début`
- `Fin`
