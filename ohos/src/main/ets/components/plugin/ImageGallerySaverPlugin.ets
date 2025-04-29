/**
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { Permissions } from '@ohos.abilityAccessCtrl';
import photoAccessHelper from '@ohos.file.photoAccessHelper'
import { fileUri, picker } from '@kit.CoreFileKit';
import { AbilityAware, AbilityPluginBinding } from '@ohos/flutter_ohos';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log'
import { reqPermissionsFromUser, checkAccessToken } from './../../utils/Permissions'
import FileMimeTypeUtil from './../../utils/FileMimeTypeUtil'
import { HashMap } from '@kit.ArkTS';
import fs from "@ohos.file.fs"
import image from '@ohos.multimedia.image'
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';

const TAG = "ImageGallerySaverPlugin"
const permissions: Array<Permissions> = ['ohos.permission.WRITE_IMAGEVIDEO']
/** ImageGallerySaverPlugin **/
export default class ImageGallerySaverPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private applicationContext: Context | null = null;
  private photoAccessHelper: photoAccessHelper.PhotoAccessHelper | null = null;
  private documentViewPicker: picker.DocumentViewPicker | null = null;
  private fileMimeType: FileMimeTypeUtil = new FileMimeTypeUtil();
  private binding: AbilityPluginBinding | null = null;

  constructor() {}

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.photoAccessHelper = photoAccessHelper.getPhotoAccessHelper(binding.getAbility().context);
    this.documentViewPicker = picker.DocumentViewPicker(binding.getAbility().context);

    this.binding = binding;
  }

  onDetachedFromAbility(): void {

  }

  getUniqueClassName(): string {
    return "ImageGallerySaverPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "image_gallery_saver");
    this.channel.setMethodCallHandler(this);
    this.applicationContext = binding.getApplicationContext();
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
  }

  async onMethodCall(call: MethodCall, result: MethodResult) {
    // 判断是否已经授权
    const state = await checkAccessToken('ohos.permission.WRITE_IMAGEVIDEO');

    if (state == abilityAccessCtrl.GrantStatus.PERMISSION_DENIED) {
      reqPermissionsFromUser(this.binding!.getAbility().context, permissions, async (error, data) => {
        let grantStatus: Array<number> = data.authResults;

        if (grantStatus[0] == abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          result.success(await this.checkMode(call));
        } else {
          result.success(SaveResultModel.toHashMap(false, null, 'Permissions is false'));
        }
      })
    } else {
      result.success(await this.checkMode(call));
    }
  }

  async checkMode(call: MethodCall) {
    switch (call.method) {
      case "saveImageToGallery":
        let image: Uint8Array = call.args.get("imageBytes");
        let name: string = call.args.get("name");
        return await this.saveImageToGallery(image, name);
      case "saveImageToDownload":
        let image: Uint8Array = call.args.get("imageBytes");
        let folder: string = call.args.get("folder");
        let name: string = call.args.get("name");
        return await this.saveImageToDownload(image, folder, name);
      case "saveFileToGallery":
        let path: string = call.args.get("file");
        let fileName: string = call.args.get("name");
        return await this.saveFileToGallery(path, fileName);
      default:
        return SaveResultModel.toHashMap(false, null, 'Method is false')
    }
  }

  // 保存图片
  async saveImageToGallery(bmp: Uint8Array, name: string):Promise<HashMap<String, ESObject>> {
    if (bmp == null) {
      return SaveResultModel.toHashMap(false, null, 'parameters error');
    }

    if (this.applicationContext == null) {
      return SaveResultModel.toHashMap(false, null, 'applicationContext is null');
    }

    let fileUri: string | null = await this.generateUri(name.split('.')[1], name.split('.')[0]);
    let outputFile: fs.File;
    let success: boolean = false;

    if (fileUri != null) {
      outputFile = fs.openSync(fileUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      try {
        await fs.write(outputFile.fd, bmp.buffer);
        success = true;
      } catch (e) {
        return SaveResultModel.toHashMap(false, null, 'write is e ' + JSON.stringify(e));
      }
      await fs.close(outputFile);
    } else {
      return SaveResultModel.toHashMap(false, null, 'fileUri is null');
    }

    if (success) {
      return SaveResultModel.toHashMap(true, fileUri, 'success save image');
    }

    return SaveResultModel.toHashMap(false, null, 'saveImageToGallery fail');
  }

  // 保存图片到下载
  async saveImageToDownload(bmp: Uint8Array, folder: string, name: string):Promise<HashMap<String, ESObject>> {
    if (bmp == null) {
      return SaveResultModel.toHashMap(false, null, 'parameters error');
    }

    if (this.applicationContext == null) {
      return SaveResultModel.toHashMap(false, null, 'applicationContext is null');
    }

    let fileUri: string | null = await this.generateDownloadUri();
    let outputFile: fs.File;
    let success: boolean = false;

    if (fileUri != null) {
      fs.mkdirSync(fileUri + folder, true);
      outputFile = fs.openSync(fileUri + folder + name, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      try {
        await fs.write(outputFile.fd, bmp.buffer);
        success = true;
      } catch (e) {
        return SaveResultModel.toHashMap(false, null, 'write is e ' + JSON.stringify(e));
      }
      await fs.close(outputFile);
    } else {
      return SaveResultModel.toHashMap(false, null, 'fileUri is null');
    }

    if (success) {
      return SaveResultModel.toHashMap(true, fileUri, 'success save image');
    }

    return SaveResultModel.toHashMap(false, null, 'saveImageToDownload fail');
  }

  // 保存文件
  async saveFileToGallery(path: string, name: string): Promise<HashMap<String, ESObject>> {
    if (path == null) {
      return SaveResultModel.toHashMap(false, null, 'parameters error');
    }

    if (this.applicationContext == null) {
      return SaveResultModel.toHashMap(false, null, 'applicationContext is null');
    }

    if (!fs.accessSync(path)) {
      return SaveResultModel.toHashMap(false, null, `${path} does not exist`);
    }

    let fileUri: string | null = await this.generateUri(path.split('.')[1], name);
    let outputFile: fs.File;
    let success: boolean = false;

    if (fileUri != null) {
      outputFile = fs.openSync(fileUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      try {
        await fs.copyFile(path, outputFile.fd);
        success = true;
      } catch (e) {
        return SaveResultModel.toHashMap(false, null, "copy file failed with error message: " + e.message + ", error code: " + e.code);
      }

      await fs.close(outputFile)
    } else {
      return SaveResultModel.toHashMap(false, null, "fileUri is null");
    }

    if (success) {
      return SaveResultModel.toHashMap(!!fileUri, fileUri, "success save file");
    }

    return SaveResultModel.toHashMap(false, null, "saveFileToGallery is fail");
  }

  // 创建相册资源，返回uri
  async generateUri(extension: string, name: string | null) {
    let fileName = name;
    let uri: string | null = null;

    if (fileName == null) {
      fileName = new Date().getTime().toString();
    }

    let photoType: photoAccessHelper.PhotoType | null = this.getMIMEType(fileName + '.' + extension);

    if (this.photoAccessHelper != null && photoType != null) {
      uri = await this.photoAccessHelper.createAsset(photoType, extension, { title: fileName });
    }

    return uri;
  }

  // 创建下载文件，返回uri
  async generateDownloadUri() {
    let uri: Array<string> | null = null;

    const documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
  
    uri = await this.documentViewPicker.save(documentSaveOptions);

    return uri[0];
  }

  // 获取类型
  getMIMEType(fileName: string):  photoAccessHelper.PhotoType | null{
    const MIMEType = this.fileMimeType.getFileMimeType(fileName);
    if (MIMEType.isVideo()) {
      return photoAccessHelper.PhotoType.VIDEO;
    } else if(MIMEType.isImage()) {
      return photoAccessHelper.PhotoType.IMAGE;
    } else {
      return null;
    }
  }
}

class SaveResultModel {
  static toHashMap(isSuccess: boolean, filePath: string | null, message: string | null):HashMap<String, ESObject> {
    let hashMap: HashMap<String, ESObject> = new HashMap();
    hashMap.set("isSuccess", isSuccess);
    hashMap.set("filePath", filePath);
    hashMap.set("message", message);
    isSuccess ? Log.d(TAG, message) : Log.e(TAG, message);

    return hashMap
  }
}