import * as fs from "node:fs"
import * as path from "node:path"

const PYTHON_EXTENSIONS = [".py", ".ipynb"]

export function walkPythonFiles(dir: string): string[] {
  const results: string[] = []
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      results.push(...walkPythonFiles(full))
    } else if (
      entry.isFile() &&
      PYTHON_EXTENSIONS.includes(path.extname(entry.name))
    ) {
      results.push(full)
    }
  }
  return results
}

/**
 * Get all directories in a Python module, by calling walkPythonFiles and getting the directory names.
 */
export function walkPythonModuleDirectories(dir: string): Set<string> {
  const directories = new Set<string>()
  for (const file of walkPythonFiles(dir)) {
    const dirName = path.dirname(file)
    directories.add(dirName)
  }
  return directories
}
