# Data

A free, portable file explorer for Windows that lets you view and edit the descriptive metadata of your photos and documents - title, subject, authors, tags, comments, copyright and rating - for one file or many at once.

Data writes **XMP metadata only**. It never changes the picture itself.


## Download

1. Go to the [latest release](https://github.com/adsnell/Data-v1/releases/latest) and download the portable zip.
2. If Windows marks it as blocked, right-click the zip, choose **Properties**, tick **Unblock**, then **OK**.
3. Unzip the **whole folder** somewhere you can write to, such as Documents. Do not run it from inside the zip, and avoid Program Files.
4. Run **Data.exe**.

Windows SmartScreen may show a blue "Windows protected your PC" message the first time, because the program is not code-signed. Choose **More info**, then **Run anyway**.

There is no installer, nothing is written to the registry, and Data does not connect to the internet. You can copy the folder to a USB stick or another PC.

## What it does

- **Browse and manage files.** Folders on the left, files in the middle, details on the right. Details and Thumbnails views with a size slider. Cut, copy, paste, delete to the Recycle Bin and drag and drop. If a name clashes, a compare window lets you Replace, Keep both, Skip or Merge.
- **Edit metadata.** Change Title, Subject, Authors, Tags, Comments, Copyright and Rating for one file or a whole selection. Add or remove tags across many files, copy and paste metadata between files, get suggestions as you type, and press 1 to 5 to set a rating.
- **Search.** Plain words, or by field (`tag:`, `title:`, `subject:`, `author:`, `comment:`, `copyright:`, `camera:`, `rating:`, `ext:`, `name:`). Exclude with a minus sign, find files that still have a blank field (`missing:subject`), narrow results with filter chips, search subfolders or several chosen folders, and re-run recent searches.
- **Batch rename from metadata**, for example `{date}_{title}`, without ever overwriting a file.
- **Careful by design.** Nothing is overwritten without asking. You can keep an `_original` backup of each changed file and use **Undo save** to restore it.
- **Light and dark look**, and adjustable text size.

## Supported files

| Kind | Types | How metadata is stored |
|---|---|---|
| Embedded XMP | JPG, TIFF, PNG, DNG, PSD, WebP, HEIC, AVIF, GIF, JPEG 2000, PDF, MP4/M4V/MOV, AI, EPS, INDD | Inside the file |
| RAW with sidecar | RAF, CR2, CR3, NEF, ARW, ORF, RW2 and other common RAW formats | In a `.xmp` file next to the RAW file; the RAW file is never modified |
| Office files | DOCX, XLSX, PPTX and similar | As native Office properties |

Other file types can be browsed and managed but not edited.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1, which comes with Windows
- ExifTool, which is bundled

## User manual

A full manual, `Data v1 - User Manual.pdf`, is included in the download and in this repository.

## Support

Data is free to use. If it saves you time and you would like to say thanks, an optional £1 is welcome at [paypal.me/AndrewSnell791](https://paypal.me/AndrewSnell791).

## Credits

All metadata reading and writing is done by [ExifTool](https://exiftool.org) by Phil Harvey. ExifTool and the other included components keep their own licences, which are in the `Licences` folder.