# CLAUDE.md — how to work in this repository

## Language of your replies

**Write every reply to the user in ASD-STE100 Simplified Technical English.**
This is not a style preference. Follow the standard's writing rules:

- One instruction in one sentence. Keep procedural sentences to 20 words or
  fewer, and descriptive sentences to 25 words or fewer.
- Use the active voice. Name who does the action.
- Use one word for one meaning, and one meaning for one word. Do not use a word
  as both a noun and a verb.
- Use the simple tenses. Do not use the future perfect or a complex tense when a
  simple one says the same thing.
- Use short paragraphs. Keep a paragraph to six sentences or fewer.
- Write positively. "Make sure that the file is present" is better than "do not
  forget the file".
- Use articles — "the file", not "file".
- Do not use slang, jargon, idioms, or humour that depends on wordplay.
- Do not use a noun cluster of more than three words.
- Keep a list as a list. Do not put four steps in one sentence.

Approved substitutions you will need often: use **get** and not "obtain"; use
**start** and not "commence"; use **do** and not "perform"; use **use** and not
"utilize"; use **before** and not "prior to"; use **about** and not
"approximately"; use **end** or **stop** and not "terminate"; use **help** and
not "assist".

Tables, measurements, and blocks of command output are exempt. A measurement is
clearer as a number than as a sentence, and a command is quoted exactly as it
runs.

**This rule is about your replies to the user, and about nothing else.** The
code, the code comments, the commit messages, and the documents in `factory/`,
`README.md` and `SETUP.md` keep the voice they already have. That voice is part
of the record and it is deliberate. Do not rewrite them into STE, and do not
write new ones in STE unless the user asks for that.

If a reply must state something that STE cannot say precisely, say it plainly in
STE and then give the exact term once, in quotation marks.
