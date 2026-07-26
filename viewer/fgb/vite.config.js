import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
    plugins: [
        tailwindcss(),
    ],
    // 相対パスで出力する。GitHub Pages のサブパス(/<repo>/fgb/)配下に置いても、
    // リポジトリ名やパスに依存せずアセットを解決できる。
    // 絶対パス(/<repo>/fgb/)にすると、リネーム時やワークフロー再実行時に
    // 古いリポジトリ名が埋め込まれて 404 になる。
    base: process.env.VITE_BASE ?? './',
});