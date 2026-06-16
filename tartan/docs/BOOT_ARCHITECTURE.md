# Boot Architecture


> **Documentation Confidence Levels**
>
> **[CERTAIN]** Verified by testing, source code, datasheets, or direct observation.
>
> **[LIKELY]** Strong supporting evidence exists, but PineRE-specific validation is incomplete.
>
> **[UNCERTAIN]** Evidence exists, but verification is currently insufficient.
>
> **[ASSUMPTION]** Planning assumption used until evidence is available.
>
> **[SPECULATION]** Idea or theory. Not suitable for engineering decisions without validation.


BootROM → idbloader → u-boot → extlinux → Kernel → DTB → Alpine
