import requests
from urllib.request import urlretrieve
from os import listdir
from os.path import isfile, join
import glob
import zipfile
import os
import subprocess
from os import listdir
from os.path import isfile, join

inventory_dir = '/home/alkis'

url_list = []

base_url = 'https://www.opengeodata.nrw.de/produkte/geobasis/lk/gru_xml/'
r = requests.get(base_url + 'index.json')
for ele in r.json()['datasets']:
    for f in ele['files']:
        url_list.append(base_url + f['name'])


def run_bash():
    bash_command = """bash alkis-import.sh nas.lst"""
    bash_command_process = subprocess.Popen(
        bash_command, shell=True, executable='/bin/bash', cwd="/home/alkisimport")
    bash_command_process.wait()
    return


def download_file(url, dst):
    local_filename = dst
    # NOTE the stream=True parameter below
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(local_filename, 'wb') as f:
            for chunk in r.iter_content(chunk_size=8192):
                # If you have chunk encoded response uncomment if
                # and set chunk_size parameter to None.
                # if chunk:
                f.write(chunk)
    return local_filename


c = 0
for url in url_list:

    dst = inventory_dir + url.rsplit('/', 1)[1]
    try:
        download_file(url, dst)
    except Exception as e:
        url_list.append(url)

    path = os.path.join(inventory_dir, 'nw', url.rsplit('/', 1)[1])
    try:
        os.mkdir(path)
    except:
        pass
    with zipfile.ZipFile(dst, "r") as zip_ref:
        zip_ref.extractall(path)

    files = [f for f in listdir(path) if isfile(join(path, f))]

    if c == 0:
        with open('/home/alkisimport/nas.lst', 'w') as nas_lst:
            nas_lst.write(
                'PG:dbname=alkis_nw user=postgres password=EdztJnCYFxhC9H\n')
            nas_lst.write('epsg 25832\n')
            nas_lst.write('skipfailuresregex .*\n')
            nas_lst.write('create\n')
            nas_lst.write('clean\n')
            nas_lst.write('options --config PG_USE_COPY NO\n')
            nas_lst.write('log\n')
            for f in files:
                nas_lst.write('{0}/{1}\n'.format(path, f))
            nas_lst.write('postprocess')

    else:
        with open('/home/alkisimport/nas.lst', 'w') as nas_lst:
            nas_lst.write(
                'PG:dbname=alkis_nw user=postgres password=EdztJnCYFxhC9H\n')
            nas_lst.write('epsg 25832\n')
            nas_lst.write('skipfailuresregex .*\n')
            nas_lst.write('update\n')
            nas_lst.write('options --config PG_USE_COPY NO\n')
            nas_lst.write('log\n')
            for f in files:
                nas_lst.write('{0}/{1}\n'.format(path, f))
            nas_lst.write('postprocess')

    os.remove(dst)
    run_bash()
    c += 1
    print(url)
